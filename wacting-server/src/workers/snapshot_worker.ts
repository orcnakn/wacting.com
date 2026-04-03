/**
 * snapshot_worker.ts — Tier-Based Daily Snapshot
 * BullMQ repeatable job — runs at midnight UTC every day.
 *
 * Member Reward Phase:
 *   1. Load all active campaigns (except EMERGENCY) with their members
 *   2. For each campaign, rank members by effectiveWac (stakedWac × multiplier)
 *   3. Assign tier-based WAC rewards per member rank
 *   4. SUPPORT: full WAC reward, hype decay (-1/day)
 *   5. REFORM: WAC × time multiplier (0.5x→10x), update multiplier
 *   6. PROTEST: full WAC reward (RAC temporarily disabled)
 *   7. Update multipliers for next cycle
 */

import { Queue, Worker, Job } from 'bullmq';
import { PrismaClient, Prisma } from '@prisma/client';
import {
    computeCampaignMemberRewards,
    computeAllCampaignRewards,
    CampaignRewardInput,
    MemberRewardInput,
} from '../engine/reward_calculator.js';
import { buildMerkleTree } from '../engine/merkle_builder.js';
import { recordChainedTransaction } from '../engine/chain_engine.js';
import { SocketManager } from '../socket/socket_manager.js';
import { refreshProfileLevel } from '../engine/profile_level_calculator.js';

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

        // ── LOAD CAMPAIGNS WITH MEMBERS ──────────────────────────────────

        const activeCampaigns = await (prisma as any).campaign.findMany({
            where: {
                isActive: true,
                totalWacStaked: { gt: 0 },
                stanceType: { not: 'EMERGENCY' },
            },
            select: {
                id: true,
                leaderId: true,
                totalWacStaked: true,
                stanceType: true,
                targetCampaignId: true,
                members: {
                    select: {
                        userId: true,
                        stakedWac: true,
                        multiplier: true,
                        joinedAt: true,
                    },
                    orderBy: { joinedAt: 'asc' },
                },
            },
        });

        if (activeCampaigns.length === 0) {
            console.log('[Snapshot] No active campaigns with staked WAC. Skipping.');
            return;
        }

        // ── COMPUTE MEMBER REWARDS PER CAMPAIGN ──────────────────────────

        interface RewardEntry {
            userId: string;
            campaignId: string;
            wacReward: number;
            rank: number;
            newMultiplier: number;
        }

        const allRewardEntries: RewardEntry[] = [];
        let totalWacRewarded = 0;

        // Track campaign-level total rewards for dailyRankingPoints
        const campaignTotalRewards = new Map<string, number>();

        for (const campaign of activeCampaigns) {
            const members: MemberRewardInput[] = (campaign as any).members.map((m: any) => {
                const daysSinceJoin = Math.floor(
                    (now.getTime() - new Date(m.joinedAt).getTime()) / 86_400_000
                );
                return {
                    userId: m.userId,
                    campaignId: campaign.id,
                    stakedWac: Number(m.stakedWac),
                    multiplier: m.multiplier,
                    stanceType: (campaign as any).stanceType as any,
                    daysSinceJoin,
                };
            });

            const results = computeCampaignMemberRewards(members);

            let campaignWacTotal = 0;
            for (const r of results) {
                allRewardEntries.push({
                    userId: r.userId,
                    campaignId: r.campaignId,
                    wacReward: r.wacReward,
                    rank: r.rank,
                    newMultiplier: r.newMultiplier,
                });
                campaignWacTotal += r.wacReward;
                totalWacRewarded += r.wacReward;
            }

            campaignTotalRewards.set(campaign.id, campaignWacTotal);
        }

        // ── COMPUTE CAMPAIGN-LEVEL REWARDS ────────────────────────────────

        const campaignInputs: CampaignRewardInput[] = activeCampaigns.map((c: any) => ({
            campaignId: c.id,
            leaderId: c.leaderId,
            totalWacStaked: Number((c as any).totalWacStaked),
        }));

        const campaignRewardEntries = computeAllCampaignRewards(campaignInputs);
        const campaignRewardMap = new Map<string, number>();
        for (const entry of campaignRewardEntries) {
            campaignRewardMap.set(entry.campaignId, entry.rewardWac);
        }

        // ── MERKLE TREE ──────────────────────────────────────────────────

        const merkleInput = allRewardEntries
            .filter((e) => e.wacReward > 0)
            .map((e) => ({
                userId: e.userId,
                epoch,
                rewardWac: e.wacReward,
            }));

        const { root } = buildMerkleTree(merkleInput);

        // ── TREASURY BALANCE ─────────────────────────────────────────────

        const treasury = await prisma.treasury.findUnique({ where: { id: 'singleton' } });
        const treasuryBalance = Number((treasury as any)?.devBalance ?? 0);

        // ── PERSIST (ATOMIC) ─────────────────────────────────────────────

        await prisma.$transaction(async (tx) => {
            // Create snapshot header
            const snapshot = await tx.dailySnapshot.create({
                data: {
                    epoch,
                    merkleRoot: root,
                    totalUsers: allRewardEntries.length,
                    totalRewarded: new Prisma.Decimal(totalWacRewarded.toFixed(6)),
                    treasuryBalance: new Prisma.Decimal(treasuryBalance.toFixed(6)),
                },
            });

            // WAC snapshot entries (per member with WAC reward)
            const snapshotEntries = allRewardEntries
                .filter((e) => e.wacReward > 0)
                .map((e, i) => ({
                    snapshotId: snapshot.id,
                    userId: e.userId,
                    rank: i + 1,
                    usersBelow: allRewardEntries.length - i - 1,
                    rewardWac: new Prisma.Decimal(e.wacReward.toFixed(6)),
                }));

            if (snapshotEntries.length > 0) {
                await tx.snapshotEntry.createMany({ data: snapshotEntries });
            }

            // Process each member reward
            for (const entry of allRewardEntries) {
                // Add WAC reward to member's balance
                if (entry.wacReward > 0) {
                    await tx.userWac.upsert({
                        where: { userId: entry.userId },
                        update: {
                            wacBalance: { increment: new Prisma.Decimal(entry.wacReward.toFixed(6)) },
                        },
                        create: {
                            userId: entry.userId,
                            wacBalance: new Prisma.Decimal(entry.wacReward.toFixed(6)),
                            isActive: true,
                        },
                    });

                    await recordChainedTransaction(tx, {
                        userId: entry.userId,
                        amount: entry.wacReward.toFixed(6),
                        type: 'WAC_DAILY_REWARD' as any,
                        note: `Daily reward — epoch ${epoch}, campaign ${entry.campaignId}, rank #${entry.rank}`,
                        campaignId: entry.campaignId,
                        epochDay: epoch,
                    });
                }

                // Update member multiplier for next cycle
                await (tx as any).campaignMember.update({
                    where: {
                        campaignId_userId: {
                            campaignId: entry.campaignId,
                            userId: entry.userId,
                        },
                    },
                    data: { multiplier: entry.newMultiplier },
                });
            }

            // Update campaign dailyRankingPoints (for RAC decay offset)
            for (const [campaignId, totalReward] of campaignTotalRewards) {
                await tx.campaign.update({
                    where: { id: campaignId },
                    data: { dailyRankingPoints: totalReward } as any,
                });
            }

            // Send notifications (batch per user — one per campaign)
            const userNotifs = new Map<string, { wac: number; campaigns: string[] }>();
            for (const entry of allRewardEntries) {
                if (entry.wacReward <= 0) continue;
                const existing = userNotifs.get(entry.userId) ?? { wac: 0, campaigns: [] };
                existing.wac += entry.wacReward;
                existing.campaigns.push(entry.campaignId);
                userNotifs.set(entry.userId, existing);
            }

            for (const [userId, data] of userNotifs) {
                const message = `Bugun +${data.wac.toFixed(4)} WAC kazandiniz!`;

                const notif = await tx.notification.create({
                    data: {
                        userId,
                        type: 'DAILY_WAC_REWARD' as any,
                        title: 'Gunluk Odul',
                        message,
                        data: JSON.stringify({
                            totalWac: data.wac.toFixed(6),
                            campaigns: data.campaigns,
                            epoch,
                        }),
                    },
                });
                SocketManager.notifyUser(userId, notif);
            }
        });

        // ── LOG ──────────────────────────────────────────────────────────

        console.log(
            `[Snapshot] Epoch ${epoch} done. ` +
            `Campaigns: ${activeCampaigns.length}, ` +
            `Members rewarded: ${allRewardEntries.length}, ` +
            `WAC distributed: ${totalWacRewarded.toFixed(6)}, ` +
            `Merkle root: ${root}`
        );

        // ── REFRESH ALL PROFILE LEVELS ─────────────────────────────────
        console.log('[Snapshot] Refreshing profile levels...');
        const allUsers = await prisma.user.findMany({
            select: { id: true },
        });
        for (const user of allUsers) {
            await refreshProfileLevel(prisma, user.id);
        }
        console.log(`[Snapshot] Profile levels refreshed for ${allUsers.length} users.`);
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
