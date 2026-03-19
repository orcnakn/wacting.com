import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';

const prisma = new PrismaClient();

export async function feedRoutes(fastify: FastifyInstance) {

    // Helper: Authenticate token (mocked for now, assuming standard auth decorator exists)
    // fastify.addHook('onRequest', async (request, reply) => { ... });

    // ─────────────────────────────────────────────────────────────────────────────
    // 1. KAMPANYALAR (CAMPAIGNS)
    // ─────────────────────────────────────────────────────────────────────────────

    // GET /feed/campaigns/active - Campaigns I am part of (WAC and RAC)
    fastify.get('/campaigns/active', async (request, reply) => {
        try {
            const user = (request as any).user || { id: 'mockUserId_1' }; // Mock fallback for testing

            // 1. WAC Campaign (My own campaign)
            const myCampaign = await prisma.icon.findUnique({
                where: { userId: user.id },
                include: { user: true }
            });

            // 2. RAC Campaigns (Protests I joined)
            const myRacPools = await (prisma as any).racPoolParticipant.findMany({
                where: { userId: user.id },
                include: {
                    pool: {
                        include: { targetUser: true, representative: true }
                    }
                }
            });

            return reply.send({
                success: true,
                wacCampaign: myCampaign,
                racCampaigns: myRacPools
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch active campaigns' });
        }
    });

    // GET /feed/campaigns/passive - Campaigns I exited
    fastify.get('/campaigns/passive', async (request, reply) => {
        try {
            const user = (request as any).user || { id: 'mockUserId_1' };
            const history = await (prisma as any).campaignHistory.findMany({
                where: { userId: user.id },
                orderBy: { exitedAt: 'desc' }
            });
            return reply.send({ success: true, history });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Server error' });
        }
    });

    // GET /feed/campaigns/following - Campaigns I follow (via campaign leader)
    fastify.get('/campaigns/following', async (request, reply) => {
        try {
            const user = (request as any).user || { id: 'mockUserId_1' };
            const followed = await (prisma as any).campaignFollow.findMany({
                where: { followerId: user.id },
                include: {
                    target: { include: { icon: true } }
                }
            });

            // Enrich with campaign data for each followed leader
            const campaigns: any[] = [];
            for (const f of followed) {
                const targetId = f.targetId;
                const campaign = await prisma.campaign.findFirst({
                    where: { leaderId: targetId, isActive: true },
                    include: {
                        _count: { select: { members: true } },
                    }
                });
                if (campaign) {
                    campaigns.push({
                        ...campaign,
                        memberCount: campaign._count?.members ?? 0,
                        leader: f.target,
                        followedAt: f.createdAt,
                    });
                }
            }
            return reply.send({ success: true, campaigns });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Server error' });
        }
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // 2. KİŞİSEL (PERSONAL)
    // ─────────────────────────────────────────────────────────────────────────────

    // GET /feed/personal/followers
    fastify.get('/personal/followers', async (request, reply) => {
        try {
            const user = (request as any).user || { id: 'mockUserId_1' };
            const followers = await prisma.follow.findMany({
                where: { followingId: user.id, status: 'APPROVED' },
                include: {
                    follower: {
                        select: {
                            id: true, email: true, avatarUrl: true, slogan: true,
                            instagramId: true, facebookId: true
                        }
                    }
                } // Note: Schema has facebookUrl/instagramUrl as recent additions, but let's just select all for now to avoid TS errors on un-generated schema
            });
            return reply.send({ success: true, followers });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Server error' });
        }
    });

    // GET /feed/personal/following
    fastify.get('/personal/following', async (request, reply) => {
        try {
            const user = (request as any).user || { id: 'mockUserId_1' };
            const following = await prisma.follow.findMany({
                where: { followerId: user.id, status: 'APPROVED' },
                include: { following: true } // Select all due to ungenerated Prisma client
            });
            return reply.send({ success: true, following });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Server error' });
        }
    });

    // POST /feed/personal/message/:userId
    fastify.post('/personal/message/:userId', async (request, reply) => {
        try {
            const user = (request as any).user || { id: 'mockUserId_1' };
            const { userId: receiverId } = request.params as { userId: string };
            const { content } = request.body as { content: string };

            if (!content) return reply.status(400).send({ success: false, error: 'Message content required' });

            const msg = await (prisma as any).directMessage.create({
                data: { senderId: user.id, receiverId, content }
            });

            return reply.send({ success: true, message: msg });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Server error' });
        }
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // 3. GLOBAL
    // ─────────────────────────────────────────────────────────────────────────────

    // GET /feed/global/popular
    fastify.get('/global/popular', async (request, reply) => {
        // Mock data logic until real area sorting is available
        const popular = await prisma.icon.findMany({
            take: 10,
            // Skip order by auraRadius since it's not generated in schema yet
            include: { user: true }
        });
        return reply.send({ success: true, popular });
    });

    // GET /feed/global/worst
    fastify.get('/global/worst', async (request, reply) => {
        const worst = await (prisma as any).racPool.findMany({
            take: 10,
            orderBy: { totalBalance: 'desc' },
            include: { targetUser: true }
        });
        return reply.send({ success: true, worst });
    });

    // GET /feed/global/local
    // Expects ?lat=X&lng=Y
    fastify.get('/global/local', async (request, reply) => {
        // Skipping PostGIS raw query for now, returning mock
        return reply.send({ success: true, local: [] });
    });
}
