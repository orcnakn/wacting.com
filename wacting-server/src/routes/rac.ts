/**
 * rac.ts — RAC Protest Token Routes (Campaign-based)
 *
 * POST /rac/pool/deposit       — deposit RAC into a protest pool against a campaign
 * GET  /rac/pool/:campaignId   — view active protest pool for a campaign
 * GET  /rac/balance            — my current RAC wallet balance
 */

import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import jwt from 'jsonwebtoken';
import { recordChainedTransaction } from '../engine/chain_engine.js';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

// ─── Schemas ─────────────────────────────────────────────────────────────────

const depositSchema = z.object({
    targetCampaignId: z.string().uuid('targetCampaignId must be a valid UUID'),
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
    // Deposits integer RAC into a protest pool against a campaign.
    // Creates the pool if it's the first depositor.
    fastify.post('/rac/pool/deposit', async (request, reply) => {
        try {
            const userId = (request as any).userId as string;
            const { targetCampaignId, amount } = depositSchema.parse(request.body);

            // Check target campaign exists and user is NOT a member
            const campaign = await prisma.campaign.findUnique({
                where: { id: targetCampaignId },
                include: { members: { where: { userId }, take: 1 } },
            });
            if (!campaign || !campaign.isActive) {
                return reply.code(404).send({ error: 'Kampanya bulunamadı.' });
            }
            if (campaign.members.length > 0) {
                return reply.code(400).send({ error: 'Kendi kampanyanızı protesto edemezsiniz.' });
            }

            // Check user's RAC wallet
            const userRac = await prisma.userRac.findUnique({ where: { userId } });
            if (!userRac || BigInt(amount) > userRac.racBalance) {
                return reply.code(400).send({
                    error: 'Yetersiz RAC bakiyesi.',
                    have: userRac ? Number(userRac.racBalance) : 0,
                    need: amount,
                });
            }

            const amountBig = BigInt(amount);

            await prisma.$transaction(async (tx) => {
                // Deduct from user's RAC wallet
                await tx.userRac.update({
                    where: { userId },
                    data: { racBalance: { decrement: amountBig } },
                });

                // Upsert pool — create if first depositor
                const existingPool = await (tx as any).racPool.findUnique({
                    where: { targetCampaignId },
                });

                if (!existingPool) {
                    // First depositor → creates pool and becomes representative
                    const pool = await (tx as any).racPool.create({
                        data: {
                            targetCampaignId,
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
                        throw new Error('Bu protesto havuzu çözülmüş.');
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
                        await (tx as any).racPool.update({
                            where: { id: existingPool.id },
                            data: { totalBalance: { increment: amountBig } },
                        });
                    } else {
                        // New participant
                        await tx.racPoolParticipant.create({
                            data: { poolId: existingPool.id, userId, contribution: amountBig },
                        });
                        await (tx as any).racPool.update({
                            where: { id: existingPool.id },
                            data: {
                                totalBalance: { increment: amountBig },
                                participantCount: { increment: 1 },
                            },
                        });
                    }
                }

                // Chained transaction record
                await recordChainedTransaction(tx, {
                    userId,
                    amount: String(amount),
                    type: 'RAC_POOL_DEPOSIT' as any,
                    note: `Deposited ${amount} RAC into protest pool for campaign ${targetCampaignId}`,
                    campaignId: targetCampaignId,
                });
            });

            const pool = await (prisma as any).racPool.findUnique({
                where: { targetCampaignId },
            });

            fastify.log.info(`[RAC] User ${userId} deposited ${amount} RAC → pool for campaign ${targetCampaignId}`);
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

    // ── POST /rac/transfer ────────────────────────────────────────────────────
    fastify.post('/rac/transfer', async (request, reply) => {
        try {
            const userId = (request as any).userId as string;
            const { toWalletId, amount } = request.body as { toWalletId: string; amount: number };

            if (!toWalletId || !amount || !Number.isInteger(amount) || amount < 1) {
                return reply.code(400).send({ error: 'toWalletId and positive integer amount required' });
            }

            const recipient = await prisma.user.findUnique({
                where: { walletId: toWalletId },
                select: { id: true },
            });
            if (!recipient) {
                return reply.code(404).send({ error: 'Cuzdan bulunamadi.' });
            }
            if (recipient.id === userId) {
                return reply.code(400).send({ error: 'Kendi cuzdaniniza transfer yapamazsiniz.' });
            }

            const senderRac = await prisma.userRac.findUnique({ where: { userId } });
            const amountBig = BigInt(amount);
            if (!senderRac || senderRac.racBalance < amountBig) {
                return reply.code(400).send({ error: 'Yetersiz RAC bakiyesi.' });
            }

            await prisma.$transaction(async (tx) => {
                await tx.userRac.update({
                    where: { userId },
                    data: { racBalance: { decrement: amountBig } },
                });

                await tx.userRac.upsert({
                    where: { userId: recipient.id },
                    update: { racBalance: { increment: amountBig } },
                    create: { userId: recipient.id, racBalance: amountBig },
                });

                await recordChainedTransaction(tx, {
                    userId,
                    amount: String(amount),
                    type: 'RAC_TRANSFER' as any,
                    note: `RAC transfer to ${toWalletId}: ${amount} RAC`,
                    campaignId: null,
                });
            });

            fastify.log.info(`[RAC] Transfer ${amount} RAC from ${userId} to ${recipient.id}`);
            return reply.send({ success: true, transferred: amount });
        } catch (err: any) {
            fastify.log.error(`[RAC] Transfer error: ${err}`);
            return reply.code(400).send({ error: err.message ?? 'Transfer failed' });
        }
    });
}

// ─── Public Routes ────────────────────────────────────────────────────────────

export async function racPublicRoutes(fastify: FastifyInstance) {

    // ── GET /rac/pool/:campaignId ─────────────────────────────────────────────
    fastify.get('/rac/pool/:campaignId', async (request, reply) => {
        try {
            const { campaignId } = request.params as { campaignId: string };

            const pool = await (prisma as any).racPool.findUnique({
                where: { targetCampaignId: campaignId },
                include: {
                    representative: { select: { id: true, slogan: true, avatarUrl: true } },
                    targetCampaign: { select: { id: true, title: true, slogan: true } },
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
                targetCampaign: pool.targetCampaign,
                topParticipants: pool.participants.map((p: any) => ({
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
