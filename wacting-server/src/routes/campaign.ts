import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { authenticateToken } from '../middleware/auth.js';

const prisma = new PrismaClient();

export async function campaignRoutes(fastify: FastifyInstance) {

    // All campaign routes require authentication
    fastify.addHook('onRequest', authenticateToken);

    // ── Create Campaign ──────────────────────────────────────────────────────
    fastify.post('/create', async (request, reply) => {
        try {
            const user = (request as any).user;
            const body = request.body as {
                title: string;
                slogan: string;
                description?: string;
                videoUrl?: string;
                iconColor: string;
                iconShape: number;
                instagramUrl?: string;
                twitterUrl?: string;
                facebookUrl?: string;
                tiktokUrl?: string;
                websiteUrl?: string;
            };

            if (!body.title || !body.slogan) {
                return reply.status(400).send({ success: false, error: 'Title and slogan are required.' });
            }

            const campaign = await (prisma as any).campaign.create({
                data: {
                    leaderId: user.id,
                    title: body.title,
                    slogan: body.slogan,
                    description: body.description ?? null,
                    videoUrl: body.videoUrl ?? null,
                    iconColor: body.iconColor || '#2C3E50',
                    iconShape: body.iconShape ?? 0,
                    instagramUrl: body.instagramUrl ?? null,
                    twitterUrl: body.twitterUrl ?? null,
                    facebookUrl: body.facebookUrl ?? null,
                    tiktokUrl: body.tiktokUrl ?? null,
                    websiteUrl: body.websiteUrl ?? null,
                }
            });

            // Update user's icon with campaign color/shape/slogan
            await prisma.icon.updateMany({
                where: { userId: user.id },
                data: {
                    colorHex: body.iconColor || '#2C3E50',
                    shapeIndex: body.iconShape ?? 0,
                    slogan: body.slogan.substring(0, 50),
                }
            });

            return reply.code(201).send({ success: true, campaign });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to create campaign' });
        }
    });

    // ── List My Campaigns ────────────────────────────────────────────────────
    fastify.get('/mine', async (request, reply) => {
        try {
            const user = (request as any).user;
            const campaigns = await (prisma as any).campaign.findMany({
                where: { leaderId: user.id },
                orderBy: { createdAt: 'desc' }
            });
            return reply.send({ success: true, campaigns });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch campaigns' });
        }
    });

    // ── List All Active Campaigns (Global) ───────────────────────────────────
    fastify.get('/all', async (request, reply) => {
        try {
            const campaigns = await (prisma as any).campaign.findMany({
                where: { isActive: true },
                orderBy: { createdAt: 'desc' },
                take: 50,
                include: {
                    leader: {
                        select: { id: true, slogan: true, avatarUrl: true }
                    }
                }
            });
            return reply.send({ success: true, campaigns });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch campaigns' });
        }
    });

    // ── Get Single Campaign ──────────────────────────────────────────────────
    fastify.get('/:id', async (request, reply) => {
        try {
            const { id } = request.params as { id: string };
            const campaign = await (prisma as any).campaign.findUnique({
                where: { id },
                include: {
                    leader: {
                        select: { id: true, slogan: true, avatarUrl: true }
                    }
                }
            });
            if (!campaign) {
                return reply.status(404).send({ success: false, error: 'Campaign not found' });
            }
            return reply.send({ success: true, campaign });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Server error' });
        }
    });
}
