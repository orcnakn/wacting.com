/**
 * rac.ts — RAC Protest Token Routes
 *
 * POST /rac/pool/deposit  — deposit RAC into a protest pool (creates pool if first)
 * GET  /rac/pool/:targetUserId — view active protest pool for a campaign
 * GET  /rac/balance        — my current RAC wallet balance
 */

import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import jwt from 'jsonwebtoken';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

// ─── Schemas ─────────────────────────────────────────────────────────────────

const depositSchema = z.object({
    targetUserId: z.string().uuid('targetUserId must be a valid user UUID'),
    amount: z.number().int('RAC amount must be an integer').positive(),
});

// ─── Auth Hook ───────────────────────────────────────────────────────────────

function requireAuth(fastify: FastifyInstance) {
    fastify.addHook('preHandler', async (request, reply) => {
        const authHeader = request.headers.authorization;
        if (!authHeader) return reply.code(401).send({ error: 'Missing token' });
        try {
            const token = authHeader.split(' ')[1];
            const decoded = jwt.verify(token!, JWT_SECRET) as any;
            (request as any).userId = decoded.userId;
        } catch {
            return reply.code(401).send({ error: 'Invalid token' });
        }
    });
}

// ─── Authenticated Routes ────────────────────────────────────────────────────

export async function racRoutes(fastify: FastifyInstance) {
    requireAuth(fastify);

    // ── POST /rac/pool/deposit ────────────────────────────────────────────────
    // Deposits integer RAC into a protest pool. Creates the pool if it's the first depositor.
    fastify.post('/rac/pool/deposit', async (request, reply) => {
        try {
            const userId = (request as any).userId as string;
            const { targetUserId, amount } = depositSchema.parse(request.body);

            if (userId === targetUserId) {
                return reply.code(400).send({ error: 'Cannot protest your own campaign' });
            }

            // Check user's RAC wallet
            const userRac = await prisma.userRac.findUnique({ where: { userId } });
            if (!userRac || BigInt(amount) > userRac.racBalance) {
                return reply.code(400).send({
                    error: 'Insufficient RAC balance',
                    have: userRac ? Number(userRac.racBalance) : 0,
                    need: amount,
                });
            }

            // Verify target campaign exists
            const target = await prisma.user.findUnique({ where: { id: targetUserId } });
            if (!target) return reply.code(404).send({ error: 'Target campaign not found' });

            const amountBig = BigInt(amount);

            await prisma.$transaction(async (tx) => {
                // Deduct from user's RAC wallet
                await tx.userRac.update({
                    where: { userId },
                    data: { racBalance: { decrement: amountBig } },
                });

                // Upsert pool — create if first depositor (they become representative)
                const existingPool = await tx.racPool.findUnique({ where: { targetUserId } });

                if (!existingPool) {
                    // First depositor → creates pool and becomes representative
                    const pool = await tx.racPool.create({
                        data: {
                            targetUserId,
                            representativeId: userId,
                            totalBalance: amountBig,
                            participantCount: 1,
                        },
                    });
                    await tx.racPoolParticipant.create({
                        data: { poolId: pool.id, userId, contribution: amountBig },
                    });
                } else {
                    if (!existingPool.isActive) {
                        throw new Error('This protest pool has been dissolved');
                    }

                    // Check if user already in pool
                    const existing = await tx.racPoolParticipant.findUnique({
                        where: { poolId_userId: { poolId: existingPool.id, userId } },
                    });

                    if (existing) {
                        // Add to existing contribution
                        await tx.racPoolParticipant.update({
                            where: { poolId_userId: { poolId: existingPool.id, userId } },
                            data: { contribution: { increment: amountBig } },
                        });
                    } else {
                        // New participant
                        await tx.racPoolParticipant.create({
                            data: { poolId: existingPool.id, userId, contribution: amountBig },
                        });
                        await tx.racPool.update({
                            where: { id: existingPool.id },
                            data: {
                                totalBalance: { increment: amountBig },
                                participantCount: { increment: 1 },
                            },
                        });
                        return; // skip double totalBalance update below
                    }

                    await tx.racPool.update({
                        where: { id: existingPool.id },
                        data: { totalBalance: { increment: amountBig } },
                    });
                }

                // Log transaction
                await tx.transaction.create({
                    data: {
                        userId,
                        amount: String(amount), // store as string for Decimal field
                        type: 'RAC_POOL_DEPOSIT',
                        note: `Deposited ${amount} RAC into protest pool for ${targetUserId}`,
                    },
                });
            });

            const pool = await prisma.racPool.findUnique({ where: { targetUserId } });

            fastify.log.info(`[RAC] User ${userId} deposited ${amount} RAC → pool for ${targetUserId}`);
            return reply.send({
                success: true,
                poolTotalBalance: Number(pool!.totalBalance),
                poolParticipants: pool!.participantCount,
            });
        } catch (err: any) {
            fastify.log.error(`[RAC] Deposit error: ${err.message}`);
            return reply.code(400).send({ error: err.message ?? 'Deposit failed' });
        }
    });

    // ── GET /rac/balance ──────────────────────────────────────────────────────
    fastify.get('/rac/balance', async (request, reply) => {
        try {
            const userId = (request as any).userId as string;
            const rac = await prisma.userRac.findUnique({ where: { userId } });
            return reply.send({
                racBalance: rac ? Number(rac.racBalance) : 0,
            });
        } catch (err: any) {
            return reply.code(500).send({ error: 'Failed to fetch RAC balance' });
        }
    });
}

// ─── Public Routes ────────────────────────────────────────────────────────────

export async function racPublicRoutes(fastify: FastifyInstance) {

    // ── GET /rac/pool/:targetUserId ───────────────────────────────────────────
    fastify.get('/rac/pool/:targetUserId', async (request, reply) => {
        try {
            const { targetUserId } = request.params as { targetUserId: string };

            const pool = await prisma.racPool.findUnique({
                where: { targetUserId },
                include: {
                    representative: { select: { id: true, slogan: true, avatarUrl: true } },
                    targetUser: { select: { id: true, slogan: true, avatarUrl: true } },
                    participants: {
                        select: { userId: true, contribution: true, joinedAt: true },
                        orderBy: { contribution: 'desc' },
                        take: 50,
                    },
                },
            });

            if (!pool) {
                return reply.send({ exists: false, isActive: false });
            }

            return reply.send({
                exists: true,
                isActive: pool.isActive,
                totalBalance: Number(pool.totalBalance),
                participantCount: pool.participantCount,
                representative: pool.representative,
                targetUser: pool.targetUser,
                topParticipants: pool.participants.map((p) => ({
                    userId: p.userId,
                    contribution: Number(p.contribution),
                    joinedAt: p.joinedAt,
                })),
            });
        } catch (err: any) {
            return reply.code(500).send({ error: 'Failed to fetch protest pool' });
        }
    });
}
