/**
 * wac.ts — WAC Economy Routes
 *
 * POST /wac/deposit        — Add WAC to ranking system
 * POST /wac/exit           — Full exit (70% user, 30% treasury)
 * GET  /wac/leaderboard    — Paginated public ranking
 * GET  /wac/status         — My WAC balance + rank (auth required)
 * GET  /wac/claim-proof    — Merkle proof for latest unclaimed reward
 */

import { FastifyInstance } from 'fastify';
import { PrismaClient, Prisma } from '@prisma/client';
import { z } from 'zod';
import jwt from 'jsonwebtoken';
import { buildRankedList } from '../engine/ranking_engine.js';
import { recordChainedTransaction } from '../engine/chain_engine.js';
import { formatWac } from '../engine/reward_calculator.js';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

// ─── Schemas ─────────────────────────────────────────────────────────────────

const depositSchema = z.object({
    amount: z.string().regex(/^\d+(\.\d{1,6})?$/, 'Invalid WAC amount'),
});

const claimProofQuery = z.object({
    epoch: z.string().optional(),
});

const leaderboardQuery = z.object({
    page: z.string().default('1'),
    limit: z.string().default('50'),
});

// ─── Auth Helper ─────────────────────────────────────────────────────────────

function requireAuth(fastify: FastifyInstance) {
    fastify.addHook('preHandler', async (request, reply) => {
        const authHeader = request.headers.authorization;
        if (!authHeader) return reply.code(401).send({ error: 'Missing token' });
        try {
            const token = authHeader.split(' ')[1]!;
            const decoded = jwt.verify(token, JWT_SECRET) as any;
            (request as any).userId = decoded.userId;
        } catch {
            return reply.code(401).send({ error: 'Invalid token' });
        }
    });
}

// ─── Route Plugin ────────────────────────────────────────────────────────────

export async function wacRoutes(fastify: FastifyInstance) {
    requireAuth(fastify);

    // ── POST /wac/deposit ─────────────────────────────────────────────────────
    fastify.post('/wac/deposit', async (request, reply) => {
        try {
            const userId = (request as any).userId as string;
            const { amount } = depositSchema.parse(request.body);
            const amountDecimal = new Prisma.Decimal(amount);

            if (amountDecimal.lte(0)) {
                return reply.code(400).send({ error: 'Deposit amount must be > 0' });
            }

            // Upsert UserWac — update balance AND tie-breaker timestamp on deposit
            const userWac = await prisma.userWac.upsert({
                where: { userId },
                update: {
                    wacBalance: { increment: amountDecimal },
                    balanceUpdatedAt: new Date(),   // explicit deposit updates tie-breaker
                    isActive: true,
                },
                create: {
                    userId,
                    wacBalance: amountDecimal,
                    balanceUpdatedAt: new Date(),
                    isActive: true,
                },
            });

            // Record chained transaction
            await prisma.$transaction(async (tx) => {
                await recordChainedTransaction(tx, {
                    userId,
                    amount: amountDecimal,
                    type: 'WAC_DEPOSIT',
                    note: `Deposit of ${amount} WAC`,
                });
            });

            fastify.log.info(`[WAC] Deposit ${amount} WAC for user ${userId}`);
            return reply.send({
                success: true,
                newBalance: userWac.wacBalance.toFixed(6),
            });
        } catch (err: any) {
            fastify.log.error(`[WAC] Deposit error: ${err}`);
            return reply.code(400).send({ error: err.message ?? 'Deposit failed' });
        }
    });

    // ── POST /wac/exit ────────────────────────────────────────────────────────
    // Full exit from liquid WAC (non-campaign balance).
    // 30% penalty: 15% burn + 15% dev, 2x penalty minted as RAC.
    fastify.post('/wac/exit', async (request, reply) => {
        try {
            const userId = (request as any).userId as string;

            const userWac = await prisma.userWac.findUnique({ where: { userId } });
            if (!userWac || !userWac.isActive) {
                return reply.code(404).send({ error: 'No active WAC position found' });
            }

            const totalBalance = userWac.wacBalance;
            if (totalBalance.lte(0)) {
                return reply.code(400).send({ error: 'Balance is zero, nothing to exit' });
            }

            // Tokenomics: 30% penalty, 70% return, 2x penalty as RAC
            const penalty = totalBalance.mul('0.30').toDecimalPlaces(6);
            const toUser = totalBalance.mul('0.70').toDecimalPlaces(6);
            const burnAmount = penalty.mul('0.50').toDecimalPlaces(6);   // 15% of total
            const devAmount = penalty.sub(burnAmount);                    // 15% of total
            const racMinted = BigInt(penalty.mul('2').floor().toFixed(0)); // 2x penalty

            await prisma.$transaction(async (tx) => {
                // Deactivate WAC position
                await tx.userWac.update({
                    where: { userId },
                    data: { wacBalance: 0, isActive: false },
                });

                // Burn 15% + Dev 15%
                await tx.treasury.upsert({
                    where: { id: 'singleton' },
                    update: {
                        burnedTotal: { increment: burnAmount },
                        devBalance: { increment: devAmount },
                    } as any,
                    create: {
                        id: 'singleton',
                        burnedTotal: burnAmount,
                        devBalance: devAmount,
                    } as any,
                });

                // Mint RAC to user wallet
                if (racMinted > 0n) {
                    await tx.userRac.upsert({
                        where: { userId },
                        update: { racBalance: { increment: racMinted } },
                        create: { userId, racBalance: racMinted },
                    });
                }

                // Chained transaction records
                await recordChainedTransaction(tx, {
                    userId,
                    amount: toUser,
                    type: 'WAC_EXIT_USER' as any,
                    note: `Full exit — 70% of ${totalBalance.toFixed(6)} WAC returned`,
                });

                await recordChainedTransaction(tx, {
                    userId,
                    amount: burnAmount,
                    type: 'WAC_BURN' as any,
                    note: `Exit — 15% burned (${burnAmount.toFixed(6)} WAC)`,
                });

                await recordChainedTransaction(tx, {
                    userId,
                    amount: devAmount,
                    type: 'WAC_DEV_FEE' as any,
                    note: `Exit — 15% dev fee (${devAmount.toFixed(6)} WAC)`,
                });

                await recordChainedTransaction(tx, {
                    userId,
                    amount: racMinted.toString(),
                    type: 'RAC_MINTED' as any,
                    note: `Exit — ${racMinted} RAC minted (2x penalty)`,
                });
            });

            fastify.log.info(
                `[WAC] Exit: user=${userId} wac=${totalBalance} toUser=${toUser} ` +
                `burned=${burnAmount} dev=${devAmount} racMinted=${racMinted}`
            );

            return reply.send({
                success: true,
                totalExited: totalBalance.toFixed(6),
                returnedToUser: toUser.toFixed(6),
                burned: burnAmount.toFixed(6),
                devFee: devAmount.toFixed(6),
                racMinted: Number(racMinted),
                message: 'Çıkış tamamlandı. WAC iadeniz ve RAC ödülünüz hesabınıza aktarıldı.',
            });
        } catch (err: any) {
            fastify.log.error(`[WAC] Exit error: ${err}`);
            return reply.code(500).send({ error: 'Exit failed' });
        }
    });

    // ── GET /wac/status ───────────────────────────────────────────────────────
    fastify.get('/wac/status', async (request, reply) => {
        try {
            const userId = (request as any).userId as string;

            const userWac = await prisma.userWac.findUnique({ where: { userId } });
            if (!userWac || !userWac.isActive) {
                return reply.send({
                    isActive: false,
                    wacBalance: '0.000000',
                    rank: null,
                    usersBelow: null,
                });
            }

            // Fetch all active for live ranking
            const allActive = await prisma.userWac.findMany({
                where: { isActive: true },
                select: { userId: true, wacBalance: true, balanceUpdatedAt: true },
            });

            const ranked = buildRankedList(
                allActive.map((u) => ({
                    userId: u.userId,
                    wacBalance: Number(u.wacBalance),
                    balanceUpdatedAt: u.balanceUpdatedAt,
                }))
            );

            const myRank = ranked.find((r) => r.userId === userId);

            return reply.send({
                isActive: true,
                wacBalance: formatWac(Number(userWac.wacBalance)),
                rank: myRank?.rank ?? null,
                usersBelow: myRank?.usersBelow ?? null,
                totalActive: allActive.length,
            });
        } catch (err: any) {
            fastify.log.error(`[WAC] Status error: ${err}`);
            return reply.code(500).send({ error: 'Failed to fetch status' });
        }
    });

    // ── GET /wac/claim-proof ──────────────────────────────────────────────────
    fastify.get('/wac/claim-proof', async (request, reply) => {
        try {
            const userId = (request as any).userId as string;
            const { epoch: epochStr } = claimProofQuery.parse(request.query);

            // Find the latest unclaimed entry for this user (or by specific epoch)
            const whereClause = epochStr
                ? { userId, claimed: false, snapshot: { epoch: Number(epochStr) } }
                : { userId, claimed: false };

            const entry = await prisma.snapshotEntry.findFirst({
                where: whereClause,
                orderBy: { snapshot: { epoch: 'desc' } },
                include: { snapshot: true },
            });

            if (!entry) {
                return reply.send({ hasPendingClaim: false });
            }

            // Rebuild proof by re-running merkle for this snapshot
            // (production: store proofs in Redis/DB; here we re-derive from snapshot data)
            // For now, return the metadata — full proof stored in Redis by snapshot_worker
            return reply.send({
                hasPendingClaim: true,
                epoch: entry.snapshot.epoch,
                rewardWac: entry.rewardWac.toFixed(6),
                merkleRoot: entry.snapshot.merkleRoot,
                rank: entry.rank,
                note: 'Request full proof via POST /wac/claim-proof/generate (coming soon)',
            });
        } catch (err: any) {
            fastify.log.error(`[WAC] Claim proof error: ${err}`);
            return reply.code(500).send({ error: 'Failed to fetch claim proof' });
        }
    });
}

// ─── Public Leaderboard (no auth) ────────────────────────────────────────────

export async function wacPublicRoutes(fastify: FastifyInstance) {
    fastify.get('/wac/leaderboard', async (request, reply) => {
        try {
            const { page: pageStr, limit: limitStr } = leaderboardQuery.parse(request.query);
            const page = Math.max(1, Number(pageStr));
            const limit = Math.min(100, Math.max(1, Number(limitStr)));
            const skip = (page - 1) * limit;

            const [allActive, total] = await prisma.$transaction([
                prisma.userWac.findMany({
                    where: { isActive: true },
                    select: { userId: true, wacBalance: true, balanceUpdatedAt: true },
                }),
                prisma.userWac.count({ where: { isActive: true } }),
            ]);

            const ranked = buildRankedList(
                allActive.map((u) => ({
                    userId: u.userId,
                    wacBalance: Number(u.wacBalance),
                    balanceUpdatedAt: u.balanceUpdatedAt,
                }))
            );

            const page_data = ranked.slice(skip, skip + limit).map((u) => ({
                rank: u.rank,
                userId: u.userId,
                wacBalance: formatWac(u.wacBalance),
                usersBelow: u.usersBelow,
            }));

            return reply.send({
                page,
                limit,
                total,
                data: page_data,
            });
        } catch (err: any) {
            fastify.log.error(`[WAC] Leaderboard error: ${err}`);
            return reply.code(500).send({ error: 'Failed to fetch leaderboard' });
        }
    });
}
