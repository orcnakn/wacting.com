/**
 * snapshot_worker.ts
 * BullMQ repeatable job — runs at midnight UTC every day.
 *
 * WAC Phase:
 *   1. Load all active UserWac rows
 *   2. Build unified ranked list (WAC + RAC pools)
 *   3. Compute WAC rewards by tier
 *   4. Auto-compound WAC (balanceUpdatedAt NOT touched)
 *   5. Build Merkle tree, persist DailySnapshot + SnapshotEntry
 *
 * RAC Phase (after WAC):
 *   6. Load all active RacPools
 *   7. Apply daily decay (−1 RAC per participant)
 *   8. Apply tier bonus (+ RAC based on pool's usersBelow rank)
 *   9. Deactivate pools where totalBalance ≤ 0
 *  10. Persist RacSnapshotEntry rows
 */

import { Queue, Worker, Job } from 'bullmq';
import { PrismaClient, Prisma } from '@prisma/client';
import {
    buildUnifiedRankedList,
    computeEffectiveTopNWac,
    UserWacRow,
    RacPoolRow,
    RacPoolRankedEntry,
} from '../engine/ranking_engine.js';
import { computeAllRewards, getTierBonus } from '../engine/reward_calculator.js';
import { buildMerkleTree } from '../engine/merkle_builder.js';

const prisma = new PrismaClient();

const REDIS_HOST = process.env.REDIS_HOST || '127.0.0.1';
const REDIS_PORT = Number(process.env.REDIS_PORT ?? 6379);
const WAC_MAX_SUPPLY = 85_016_666_666_667;

const connection = { host: REDIS_HOST, port: REDIS_PORT };

// ─── Queue ───────────────────────────────────────────────────────────────────

export const snapshotQueue = new Queue('wac-snapshot', { connection });

export async function registerSnapshotCron() {
    await snapshotQueue.upsertJobScheduler(
        'midnight-snapshot',
        { pattern: '0 0 * * *', tz: 'UTC' },
        { name: 'wac-snapshot' }
    );
    console.log('[WAC Snapshot] Cron registered: 0 0 * * * UTC');
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

        // ── LOAD DATA ────────────────────────────────────────────────────────

        const [activeWacRows, activeRacPools] = await Promise.all([
            prisma.userWac.findMany({
                where: { isActive: true },
                select: { userId: true, wacBalance: true, balanceUpdatedAt: true },
            }),
            prisma.racPool.findMany({
                where: { isActive: true },
                select: {
                    id: true,
                    targetUserId: true,
                    totalBalance: true,
                    participantCount: true,
                    createdAt: true,
                },
            }),
        ]);

        if (activeWacRows.length === 0 && activeRacPools.length === 0) {
            console.log('[Snapshot] No active users or pools. Skipping.');
            return;
        }

        // ── BUILD UNIFIED RANKING ─────────────────────────────────────────────

        const wacUsers: UserWacRow[] = activeWacRows.map((u) => ({
            userId: u.userId,
            wacBalance: Number(u.wacBalance),
            balanceUpdatedAt: u.balanceUpdatedAt,
        }));

        const racPools: RacPoolRow[] = activeRacPools.map((p) => ({
            poolId: p.id,
            targetUserId: p.targetUserId,
            totalBalance: Number(p.totalBalance),
            participantCount: p.participantCount,
            createdAt: p.createdAt,
        }));

        const unified = buildUnifiedRankedList(wacUsers, racPools);

        // ── WAC REWARDS ───────────────────────────────────────────────────────

        // Circulating WAC supply
        const [supplyAgg, exitAgg] = await Promise.all([
            prisma.transaction.aggregate({
                _sum: { amount: true },
                where: { type: { in: ['WAC_DEPOSIT', 'WAC_DAILY_REWARD'] as any } },
            }),
            prisma.transaction.aggregate({
                _sum: { amount: true },
                where: { type: 'WAC_EXIT_USER' as any },
            }),
        ]);
        const circulatingSupply =
            Number(supplyAgg._sum?.amount ?? 0) - Number(exitAgg._sum?.amount ?? 0);

        // Only WAC entries participate in WAC rewards
        const wacRanked = unified
            .filter((e) => e.type === 'WAC')
            .map((e) => ({
                userId: (e as any).userId as string,
                rank: e.rank,
                usersBelow: e.usersBelow,
            }));

        const rewardEntries = computeAllRewards(wacRanked, circulatingSupply, WAC_MAX_SUPPLY);
        const totalRewarded = rewardEntries.reduce((s, e) => s + e.rewardWac, 0);

        // ── MERKLE TREE ───────────────────────────────────────────────────────

        const merkleInput = rewardEntries
            .filter((e) => e.rewardWac > 0)
            .map((e) => ({ userId: e.userId, epoch, rewardWac: e.rewardWac }));

        const { root } = buildMerkleTree(merkleInput);

        // ── TREASURY BALANCE ──────────────────────────────────────────────────

        const treasury = await prisma.treasury.findUnique({ where: { id: 'singleton' } });
        const treasuryBalance = Number(treasury?.balance ?? 0);

        // ── RAC POOL MECHANICS ────────────────────────────────────────────────

        interface RacPoolUpdate {
            poolId: string;
            rank: number;
            usersBelow: number;
            decayAmount: bigint;
            bonusAmount: bigint;
            netChange: bigint;
            newBalance: bigint;
            shouldDeactivate: boolean;
        }

        const racPoolUpdates: RacPoolUpdate[] = unified
            .filter((e): e is RacPoolRankedEntry => e.type === 'RAC_POOL')
            .map((entry) => {
                const poolRaw = activeRacPools.find((p) => p.id === entry.poolId)!;
                const currentBalance = BigInt(poolRaw.totalBalance);
                const participantCount = BigInt(poolRaw.participantCount);

                // Decay: −1 RAC per participant
                const decayAmount = participantCount;

                // Tier bonus (same table as WAC, added as integer RAC)
                const bonusAmount = BigInt(Math.floor(getTierBonus(entry.usersBelow)));

                const netChange = bonusAmount - decayAmount;
                const rawNewBalance = currentBalance + netChange;
                const newBalance = rawNewBalance < 0n ? 0n : rawNewBalance;

                return {
                    poolId: entry.poolId,
                    rank: entry.rank,
                    usersBelow: entry.usersBelow,
                    decayAmount,
                    bonusAmount,
                    netChange,
                    newBalance,
                    shouldDeactivate: newBalance <= 0n,
                };
            });

        // ── PERSIST (ATOMIC) ──────────────────────────────────────────────────

        await prisma.$transaction(async (tx) => {
            // Create snapshot header
            const snapshot = await tx.dailySnapshot.create({
                data: {
                    epoch,
                    merkleRoot: root,
                    totalUsers: activeWacRows.length,
                    totalRewarded: new Prisma.Decimal(totalRewarded.toFixed(6)),
                    treasuryBalance: new Prisma.Decimal(treasuryBalance.toFixed(6)),
                },
            });

            // WAC snapshot entries
            await tx.snapshotEntry.createMany({
                data: rewardEntries.map((e) => ({
                    snapshotId: snapshot.id,
                    userId: e.userId,
                    rank: e.rank,
                    usersBelow: e.usersBelow,
                    rewardWac: new Prisma.Decimal(e.rewardWac.toFixed(6)),
                })),
            });

            // WAC auto-compound (balanceUpdatedAt NOT touched)
            for (const entry of rewardEntries) {
                if (entry.rewardWac <= 0) continue;
                await tx.userWac.update({
                    where: { userId: entry.userId },
                    data: {
                        wacBalance: { increment: new Prisma.Decimal(entry.rewardWac.toFixed(6)) },
                    },
                });
            }

            // WAC reward tx log
            await tx.transaction.createMany({
                data: rewardEntries
                    .filter((e) => e.rewardWac > 0)
                    .map((e) => ({
                        userId: e.userId,
                        amount: new Prisma.Decimal(e.rewardWac.toFixed(6)),
                        type: 'WAC_DAILY_REWARD' as const,
                        note: `Daily reward — epoch ${epoch}, rank ${e.rank}`,
                    })),
            });

            // RAC pool updates
            for (const update of racPoolUpdates) {
                // Persist snapshot entry for this pool
                await tx.racSnapshotEntry.create({
                    data: {
                        snapshotId: snapshot.id,
                        poolId: update.poolId,
                        rank: update.rank,
                        usersBelow: update.usersBelow,
                        decayAmount: update.decayAmount,
                        bonusAmount: update.bonusAmount,
                        netChange: update.netChange,
                    },
                });

                // Apply decay + bonus to pool balance
                await tx.racPool.update({
                    where: { id: update.poolId },
                    data: {
                        totalBalance: update.newBalance,
                        isActive: !update.shouldDeactivate,
                    },
                });

                if (update.shouldDeactivate) {
                    console.log(`[RAC] Pool ${update.poolId} dissolved at epoch ${epoch}`);
                }
            }
        });

        // ── LOG ───────────────────────────────────────────────────────────────

        const effectiveWac = computeEffectiveTopNWac(unified);
        console.log(
            `[Snapshot] Epoch ${epoch} done. ` +
            `WAC users: ${activeWacRows.length}, RAC pools: ${activeRacPools.length}, ` +
            `Rewarded: ${totalRewarded.toFixed(6)} WAC, ` +
            `Effective top-100 WAC: ${effectiveWac.toFixed(6)}, ` +
            `Icon area: ${(effectiveWac * 6).toFixed(0)} m², ` +
            `Merkle root: ${root}`
        );

        // Future: await anchorRootOnChain(root, epoch);
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
