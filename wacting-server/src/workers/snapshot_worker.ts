/**
 * snapshot_worker.ts — Campaign-based Daily Snapshot
 * BullMQ repeatable job — runs at midnight UTC every day.
 *
 * Campaign Reward Phase:
 *   1. Load all active campaigns with totalWacStaked > 0
 *   2. Compute daily reward pool: √(totalSystemStaked) × 2
 *   3. Distribute proportionally to campaign leaders
 *   4. Auto-compound WAC rewards, build Merkle tree
 *   5. Save dailyRankingPoints on each campaign
 *
 * RAC Decay Phase:
 *   6. Load all active RacPools (campaign-based)
 *   7. Apply -1 Rule: protestorCount × 1 RAC daily decay
 *   8. Offset with dailyRankingPoints (life-water)
 *   9. Deactivate pools where totalBalance ≤ 0
 */

import { Queue, Worker, Job } from 'bullmq';
import { PrismaClient, Prisma } from '@prisma/client';
import {
    computeAllCampaignRewards,
    computeRacDecay,
    CampaignRewardInput,
    RacDecayInput,
} from '../engine/reward_calculator.js';
import { buildMerkleTree } from '../engine/merkle_builder.js';
import { recordChainedTransaction } from '../engine/chain_engine.js';
import { SocketManager } from '../socket/socket_manager.js';

const prisma = new PrismaClient();

const REDIS_HOST = process.env.REDIS_HOST || '127.0.0.1';
const REDIS_PORT = Number(process.env.REDIS_PORT ?? 6379);

const connection = { host: REDIS_HOST, port: REDIS_PORT };

// ─── Queue ───────────────────────────────────────────────────────────────────

export const snapshotQueue = new Queue('wac-snapshot', { connection });

export async function registerSnapshotCron() {
    await snapshotQueue.upsertJobScheduler(
        'midnight-snapshot',
        { pattern: '0 1 * * *', tz: 'UTC' },
        { name: 'wac-snapshot' }
    );
    console.log('[WAC Snapshot] Cron registered: 0 1 * * * UTC');
}

// ─── Worker ──────────────────────────────────────────────────────────────────

export const snapshotWorker = new Worker(
    'wac-snapshot',
    async (job: Job) => {
        const now = new Date();
        const epoch = Math.floor(
            Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) / 86_400_000
        );

        console.log(`[Snapshot] Starting epoch ${epoch}`);

        // Guard — don't double-run
        const existing = await prisma.dailySnapshot.findUnique({ where: { epoch } });
        if (existing) {
            console.log(`[Snapshot] Epoch ${epoch} already processed. Skipping.`);
            return;
        }

        // ── LOAD CAMPAIGNS ─────────────────────────────────────────────────

        const activeCampaigns = await prisma.campaign.findMany({
            where: { isActive: true, totalWacStaked: { gt: 0 } } as any,
            select: {
                id: true,
                leaderId: true,
                totalWacStaked: true,
            },
        });

        if (activeCampaigns.length === 0) {
            console.log('[Snapshot] No active campaigns with staked WAC. Skipping.');
            return;
        }

        // ── COMPUTE CAMPAIGN REWARDS ────────────────────────────────────────

        const campaignInputs: CampaignRewardInput[] = activeCampaigns.map((c) => ({
            campaignId: c.id,
            leaderId: c.leaderId,
            totalWacStaked: Number((c as any).totalWacStaked),
        }));

        const rewardEntries = computeAllCampaignRewards(campaignInputs);
        const totalRewarded = rewardEntries.reduce((s, e) => s + e.rewardWac, 0);

        // ── MERKLE TREE ─────────────────────────────────────────────────────

        const merkleInput = rewardEntries
            .filter((e) => e.rewardWac > 0)
            .map((e) => ({
                userId: e.leaderId,
                epoch,
                rewardWac: e.rewardWac,
            }));

        const { root } = buildMerkleTree(merkleInput);

        // ── TREASURY BALANCE ────────────────────────────────────────────────

        const treasury = await prisma.treasury.findUnique({ where: { id: 'singleton' } });
        const treasuryBalance = Number((treasury as any)?.devBalance ?? 0);

        // ── LOAD RAC POOLS ──────────────────────────────────────────────────

        const activeRacPools = await (prisma as any).racPool.findMany({
            where: { isActive: true },
            select: {
                id: true,
                targetCampaignId: true,
                totalBalance: true,
                participantCount: true,
            },
        });

        // ── COMPUTE RAC DECAY ───────────────────────────────────────────────

        // Map campaign rewards to dailyRankingPoints for decay offset
        const campaignRewardMap = new Map<string, number>();
        for (const entry of rewardEntries) {
            campaignRewardMap.set(entry.campaignId, entry.rewardWac);
        }

        const racDecayInputs: RacDecayInput[] = activeRacPools
            .filter((p: any) => BigInt(p.totalBalance) > 0n)
            .map((p: any) => ({
                campaignId: p.targetCampaignId,
                poolId: p.id,
                totalRacBalance: BigInt(p.totalBalance),
                protestorCount: p.participantCount,
                dailyRankingPoints: campaignRewardMap.get(p.targetCampaignId) ?? 0,
            }));

        const racDecayResults = racDecayInputs.map(computeRacDecay);

        // ── PERSIST (ATOMIC) ────────────────────────────────────────────────

        await prisma.$transaction(async (tx) => {
            // Create snapshot header
            const snapshot = await tx.dailySnapshot.create({
                data: {
                    epoch,
                    merkleRoot: root,
                    totalUsers: activeCampaigns.length,
                    totalRewarded: new Prisma.Decimal(totalRewarded.toFixed(6)),
                    treasuryBalance: new Prisma.Decimal(treasuryBalance.toFixed(6)),
                },
            });

            // WAC snapshot entries (per campaign leader)
            const snapshotEntries = rewardEntries
                .filter((e) => e.rewardWac > 0)
                .map((e, i) => ({
                    snapshotId: snapshot.id,
                    userId: e.leaderId,
                    rank: i + 1,
                    usersBelow: rewardEntries.length - i - 1,
                    rewardWac: new Prisma.Decimal(e.rewardWac.toFixed(6)),
                }));

            if (snapshotEntries.length > 0) {
                await tx.snapshotEntry.createMany({ data: snapshotEntries });
            }

            // Auto-compound WAC rewards to campaign leaders
            for (const entry of rewardEntries) {
                if (entry.rewardWac <= 0) continue;

                // Add reward to leader's liquid WAC balance
                await tx.userWac.upsert({
                    where: { userId: entry.leaderId },
                    update: {
                        wacBalance: { increment: new Prisma.Decimal(entry.rewardWac.toFixed(6)) },
                    },
                    create: {
                        userId: entry.leaderId,
                        wacBalance: new Prisma.Decimal(entry.rewardWac.toFixed(6)),
                        isActive: true,
                    },
                });

                // Update campaign's dailyRankingPoints (for RAC decay offset)
                await tx.campaign.update({
                    where: { id: entry.campaignId },
                    data: { dailyRankingPoints: entry.rewardWac } as any,
                });

                // Chained tx record
                await recordChainedTransaction(tx, {
                    userId: entry.leaderId,
                    amount: entry.rewardWac.toFixed(6),
                    type: 'WAC_DAILY_REWARD' as any,
                    note: `Daily reward — epoch ${epoch}, campaign ${entry.campaignId}`,
                    campaignId: entry.campaignId,
                    epochDay: epoch,
                });

                // Daily reward notification
                const notif = await tx.notification.create({
                    data: {
                        userId: entry.leaderId,
                        type: 'DAILY_WAC_REWARD' as any,
                        title: 'Gunluk WAC Odulu',
                        message: `Bugun +${entry.rewardWac.toFixed(4)} WAC kazandiniz! (Kampanya #${entry.rank} sira)`,
                        data: JSON.stringify({
                            campaignId: entry.campaignId,
                            reward: entry.rewardWac.toFixed(6),
                            rank: entry.rank,
                            epoch,
                        }),
                    },
                });
                SocketManager.notifyUser(entry.leaderId, notif);
            }

            // RAC pool decay updates
            for (const result of racDecayResults) {
                // Persist snapshot entry
                await tx.racSnapshotEntry.create({
                    data: {
                        snapshotId: snapshot.id,
                        poolId: result.poolId,
                        rank: 0,
                        usersBelow: 0,
                        decayAmount: result.decayAmount,
                        bonusAmount: result.bonusAmount,
                        netChange: -result.netDecay,
                    },
                });

                // Apply decay to pool balance
                await (tx as any).racPool.update({
                    where: { id: result.poolId },
                    data: {
                        totalBalance: result.newBalance,
                        isActive: !result.shouldDeactivate,
                    },
                });

                // Log decay tx if any
                if (result.netDecay > 0n) {
                    await recordChainedTransaction(tx, {
                        userId: 'SYSTEM',
                        amount: result.netDecay.toString(),
                        type: 'RAC_POOL_DECAY' as any,
                        note: `RAC decay — pool ${result.poolId}, epoch ${epoch}`,
                        campaignId: result.campaignId,
                        epochDay: epoch,
                    });
                }

                if (result.shouldDeactivate) {
                    console.log(`[RAC] Pool ${result.poolId} dissolved at epoch ${epoch}`);
                }
            }
        });

        // ── LOG ─────────────────────────────────────────────────────────────

        console.log(
            `[Snapshot] Epoch ${epoch} done. ` +
            `Campaigns: ${activeCampaigns.length}, ` +
            `Rewarded: ${totalRewarded.toFixed(6)} WAC, ` +
            `RAC pools processed: ${racDecayResults.length}, ` +
            `Merkle root: ${root}`
        );
    },
    { connection }
);

// ─── Event hooks ─────────────────────────────────────────────────────────────

snapshotWorker.on('completed', (job) => {
    console.log(`[Snapshot] Job ${job.id} completed`);
});

snapshotWorker.on('failed', (job, err) => {
    console.error(`[Snapshot] Job ${job?.id} failed: ${err.message}`);
});
