/**
 * snapshot_worker.ts — Tier-Based Daily Snapshot
 * BullMQ repeatable job — runs at midnight UTC every day.
 *
 * Member Reward Phase:
 *   1. Load all active campaigns (except EMERGENCY) with their members
 *   2. For each campaign, rank members by effectiveWac (stakedWac × multiplier)
 *   3. Assign tier-based rewards per member rank
 *   4. SUPPORT: full WAC reward, hype decay (-1/day)
 *   5. REFORM: WAC × time multiplier (0.5x→10x), update multiplier
 *   6. PROTEST: half WAC + half RAC, mint RAC to protest target pool
 *   7. Update multipliers for next cycle
 *
 * RAC Decay Phase (unchanged):
 *   8. Load active RacPools
 *   9. Apply -1 Rule with dailyRankingPoints offset
 *   10. Deactivate pools where totalBalance ≤ 0
 */

import { Queue, Worker, Job } from 'bullmq';
import { PrismaClient, Prisma } from '@prisma/client';
import {
    computeCampaignMemberRewards,
    computeAllCampaignRewards,
    computeRacDecay,
    CampaignRewardInput,
    RacDecayInput,
    MemberRewardInput,
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
            racReward: number;
            rank: number;
            newMultiplier: number;
        }

        const allRewardEntries: RewardEntry[] = [];
        let totalWacRewarded = 0;
        let totalRacMinted = 0;

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
                    racReward: r.racReward,
                    rank: r.rank,
                    newMultiplier: r.newMultiplier,
                });
                campaignWacTotal += r.wacReward;
                totalWacRewarded += r.wacReward;
                totalRacMinted += r.racReward;
            }

            campaignTotalRewards.set(campaign.id, campaignWacTotal);
        }

        // ── COMPUTE CAMPAIGN-LEVEL REWARDS (for RAC decay offset) ────────

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

        // ── LOAD RAC POOLS ───────────────────────────────────────────────

        const activeRacPools = await (prisma as any).racPool.findMany({
            where: { isActive: true },
            select: {
                id: true,
                targetCampaignId: true,
                totalBalance: true,
                participantCount: true,
            },
        });

        // ── COMPUTE RAC DECAY ────────────────────────────────────────────

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

                // Mint RAC for PROTEST members
                if (entry.racReward > 0) {
                    const racAmount = BigInt(Math.floor(entry.racReward));
                    if (racAmount > 0n) {
                        // Add RAC to user's balance
                        await tx.userRac.upsert({
                            where: { userId: entry.userId },
                            update: { racBalance: { increment: racAmount } },
                            create: { userId: entry.userId, racBalance: racAmount },
                        });

                        // Find the campaign's target and deposit RAC into its pool
                        const campaign = activeCampaigns.find((c: any) => c.id === entry.campaignId);
                        const targetId = (campaign as any)?.targetCampaignId;
                        if (targetId) {
                            // Upsert RacPool for the target campaign
                            const existingPool = await (tx as any).racPool.findUnique({
                                where: { targetCampaignId: targetId },
                            });

                            if (existingPool) {
                                await (tx as any).racPool.update({
                                    where: { targetCampaignId: targetId },
                                    data: { totalBalance: { increment: racAmount } },
                                });
                            } else {
                                await (tx as any).racPool.create({
                                    data: {
                                        targetCampaignId: targetId,
                                        representativeId: campaign!.leaderId,
                                        totalBalance: racAmount,
                                        participantCount: 1,
                                        isActive: true,
                                    },
                                });
                            }

                            // Add user as participant if not already
                            const existingParticipant = await (tx as any).racPoolParticipant.findUnique({
                                where: {
                                    poolId_userId: {
                                        poolId: existingPool?.id ?? '',
                                        userId: entry.userId,
                                    },
                                },
                            }).catch(() => null);

                            if (existingPool && !existingParticipant) {
                                await (tx as any).racPoolParticipant.create({
                                    data: {
                                        poolId: existingPool.id,
                                        userId: entry.userId,
                                        contribution: racAmount,
                                    },
                                });
                                await (tx as any).racPool.update({
                                    where: { id: existingPool.id },
                                    data: { participantCount: { increment: 1 } },
                                });
                            } else if (existingPool && existingParticipant) {
                                await (tx as any).racPoolParticipant.update({
                                    where: { id: existingParticipant.id },
                                    data: { contribution: { increment: racAmount } },
                                });
                            }
                        }

                        await recordChainedTransaction(tx, {
                            userId: entry.userId,
                            amount: racAmount.toString(),
                            type: 'RAC_MINTED' as any,
                            note: `Daily PROTEST RAC — epoch ${epoch}, campaign ${entry.campaignId}`,
                            campaignId: entry.campaignId,
                            epochDay: epoch,
                        });
                    }
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
            const userNotifs = new Map<string, { wac: number; rac: number; campaigns: string[] }>();
            for (const entry of allRewardEntries) {
                if (entry.wacReward <= 0 && entry.racReward <= 0) continue;
                const existing = userNotifs.get(entry.userId) ?? { wac: 0, rac: 0, campaigns: [] };
                existing.wac += entry.wacReward;
                existing.rac += entry.racReward;
                existing.campaigns.push(entry.campaignId);
                userNotifs.set(entry.userId, existing);
            }

            for (const [userId, data] of userNotifs) {
                let message = `Bugun +${data.wac.toFixed(4)} WAC kazandiniz!`;
                if (data.rac > 0) {
                    message += ` +${data.rac.toFixed(0)} RAC uretildi!`;
                }

                const notif = await tx.notification.create({
                    data: {
                        userId,
                        type: 'DAILY_WAC_REWARD' as any,
                        title: 'Gunluk Odul',
                        message,
                        data: JSON.stringify({
                            totalWac: data.wac.toFixed(6),
                            totalRac: Math.floor(data.rac),
                            campaigns: data.campaigns,
                            epoch,
                        }),
                    },
                });
                SocketManager.notifyUser(userId, notif);
            }

            // RAC pool decay updates
            for (const result of racDecayResults) {
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

                await (tx as any).racPool.update({
                    where: { id: result.poolId },
                    data: {
                        totalBalance: result.newBalance,
                        isActive: !result.shouldDeactivate,
                    },
                });

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

        // ── LOG ──────────────────────────────────────────────────────────

        console.log(
            `[Snapshot] Epoch ${epoch} done. ` +
            `Campaigns: ${activeCampaigns.length}, ` +
            `Members rewarded: ${allRewardEntries.length}, ` +
            `WAC distributed: ${totalWacRewarded.toFixed(6)}, ` +
            `RAC minted: ${totalRacMinted.toFixed(0)}, ` +
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
