import { FastifyInstance } from 'fastify';
import { PrismaClient, Prisma } from '@prisma/client';
import { authenticateToken } from '../middleware/auth.js';

const prisma = new PrismaClient();
const CAMPAIGN_STAKE_COST = new Prisma.Decimal('1.000000');

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
                speed?: number;
                instagramUrl?: string;
                twitterUrl?: string;
                facebookUrl?: string;
                tiktokUrl?: string;
                websiteUrl?: string;
            };

            if (!body.title || !body.slogan) {
                return reply.status(400).send({ success: false, error: 'Title and slogan are required.' });
            }

            if (body.speed !== undefined && (body.speed < 0 || body.speed > 1)) {
                return reply.status(400).send({ success: false, error: 'Speed must be between 0 and 1.' });
            }

            // Check WAC balance — need at least 1 WAC to create a campaign
            const userWac = await prisma.userWac.findUnique({ where: { userId: user.id } });
            if (!userWac || !userWac.isActive || userWac.wacBalance.lt(CAMPAIGN_STAKE_COST)) {
                return reply.status(400).send({
                    success: false,
                    error: 'Kampanya olusturmak icin en az 1 WAC gerekli.',
                    requiredWac: '1.000000',
                    currentWac: userWac?.wacBalance.toFixed(6) ?? '0.000000',
                });
            }

            // Deduct 1 WAC, create campaign, add leader as member — all in one transaction
            const [campaign] = await prisma.$transaction(async (tx) => {
                await tx.userWac.update({
                    where: { userId: user.id },
                    data: {
                        wacBalance: { decrement: CAMPAIGN_STAKE_COST },
                        balanceUpdatedAt: new Date(),
                    },
                });

                await tx.transaction.create({
                    data: {
                        userId: user.id,
                        amount: CAMPAIGN_STAKE_COST,
                        type: 'WAC_DEPOSIT',
                        note: `Campaign stake: -1 WAC for "${body.title}"`,
                    },
                });

                const c = await (tx as any).campaign.create({
                    data: {
                        leaderId: user.id,
                        title: body.title,
                        slogan: body.slogan,
                        description: body.description ?? null,
                        videoUrl: body.videoUrl ?? null,
                        iconColor: body.iconColor || '#2C3E50',
                        iconShape: body.iconShape ?? 0,
                        speed: body.speed ?? 0.5,
                        instagramUrl: body.instagramUrl ?? null,
                        twitterUrl: body.twitterUrl ?? null,
                        facebookUrl: body.facebookUrl ?? null,
                        tiktokUrl: body.tiktokUrl ?? null,
                        websiteUrl: body.websiteUrl ?? null,
                    }
                });

                // Leader is automatically the first member
                await (tx as any).campaignMember.create({
                    data: { campaignId: c.id, userId: user.id }
                });

                await tx.icon.updateMany({
                    where: { userId: user.id },
                    data: {
                        colorHex: body.iconColor || '#2C3E50',
                        shapeIndex: body.iconShape ?? 0,
                        slogan: body.slogan.substring(0, 50),
                    }
                });

                return [c];
            });

            const updatedWac = await prisma.userWac.findUnique({ where: { userId: user.id } });

            return reply.code(201).send({
                success: true,
                campaign,
                wacBalance: updatedWac?.wacBalance.toFixed(6) ?? '0.000000',
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: error.message || 'Failed to create campaign' });
        }
    });

    // ── Join Campaign ────────────────────────────────────────────────────────
    fastify.post('/:id/join', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { id } = request.params as { id: string };

            const campaign = await prisma.campaign.findUnique({ where: { id } });
            if (!campaign || !campaign.isActive) {
                return reply.status(404).send({ success: false, error: 'Campaign not found.' });
            }

            const existing = await (prisma as any).campaignMember.findUnique({
                where: { campaignId_userId: { campaignId: id, userId: user.id } }
            });
            if (existing) {
                return reply.status(409).send({ success: false, error: 'Already a member of this campaign.' });
            }

            await (prisma as any).campaignMember.create({
                data: { campaignId: id, userId: user.id }
            });

            return reply.send({ success: true, message: 'Joined campaign successfully.' });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: error.message || 'Failed to join campaign' });
        }
    });

    // ── Leave Campaign (with leader succession) ───────────────────────────────
    fastify.post('/:id/leave', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { id } = request.params as { id: string };

            const campaign = await prisma.campaign.findUnique({
                where: { id },
                include: {
                    members: {
                        orderBy: { joinedAt: 'asc' },
                        include: { user: true }
                    }
                }
            });

            if (!campaign || !campaign.isActive) {
                return reply.status(404).send({ success: false, error: 'Campaign not found.' });
            }

            const isLeader = campaign.leaderId === user.id;
            const memberCount = campaign.members.length;

            await prisma.$transaction(async (tx) => {
                // Remove user from members
                await (tx as any).campaignMember.delete({
                    where: { campaignId_userId: { campaignId: id, userId: user.id } }
                });

                if (isLeader) {
                    if (memberCount <= 1) {
                        // No members left — deactivate campaign
                        await tx.campaign.update({
                            where: { id },
                            data: { isActive: false }
                        });
                    } else {
                        // Successor = earliest member who is not the current leader
                        const successor = campaign.members.find(m => m.userId !== user.id);
                        if (successor) {
                            await tx.campaign.update({
                                where: { id },
                                data: { leaderId: successor.userId }
                            });
                            fastify.log.info(`[Campaign] Leader succession: ${user.id} → ${successor.userId} for campaign ${id}`);
                        }
                    }
                }
            });

            const result = isLeader && memberCount <= 1
                ? { success: true, message: 'Campaign closed — no members remaining.' }
                : { success: true, message: isLeader ? 'You left the campaign. Leadership transferred to next member.' : 'You left the campaign.' };

            return reply.send(result);
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: error.message || 'Failed to leave campaign' });
        }
    });

    // ── Get Campaign Members ──────────────────────────────────────────────────
    fastify.get('/:id/members', async (request, reply) => {
        try {
            const { id } = request.params as { id: string };

            const campaign = await prisma.campaign.findUnique({
                where: { id },
                include: {
                    members: {
                        orderBy: { joinedAt: 'asc' },
                        include: {
                            user: {
                                select: { id: true, slogan: true, avatarUrl: true, email: true }
                            }
                        }
                    }
                }
            });

            if (!campaign) {
                return reply.status(404).send({ success: false, error: 'Campaign not found.' });
            }

            const members = campaign.members.map(m => ({
                userId: m.userId,
                joinedAt: m.joinedAt,
                isLeader: m.userId === campaign.leaderId,
                user: m.user,
            }));

            return reply.send({ success: true, members, leaderUserId: campaign.leaderId });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch members' });
        }
    });

    // ── List My Campaigns ────────────────────────────────────────────────────
    fastify.get('/mine', async (request, reply) => {
        try {
            const user = (request as any).user;
            const campaigns = await prisma.campaign.findMany({
                where: { leaderId: user.id },
                orderBy: { createdAt: 'desc' }
            });
            return reply.send({ success: true, campaigns });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch campaigns' });
        }
    });

    // ── List All Active Campaigns ─────────────────────────────────────────────
    fastify.get('/all', async (_request, reply) => {
        try {
            const campaigns = await prisma.campaign.findMany({
                where: { isActive: true },
                orderBy: { createdAt: 'desc' },
                take: 50,
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    _count: { select: { members: true, polls: true } }
                }
            });
            return reply.send({ success: true, campaigns });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch campaigns' });
        }
    });

    // ── Get Single Campaign ───────────────────────────────────────────────────
    fastify.get('/:id', async (request, reply) => {
        try {
            const { id } = request.params as { id: string };
            const campaign = await prisma.campaign.findUnique({
                where: { id },
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    _count: { select: { members: true, polls: true } }
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

    // ── Helper: Calculate distance between two points (Haversine formula) ──────
    const calcDistance = (x1: number, y1: number, x2: number, y2: number): number => {
        const R = 6371; // Earth's radius in km
        const dLat = (y2 - y1) * (Math.PI / 180);
        const dLon = (x2 - x1) * (Math.PI / 180);
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                  Math.cos(y1 * (Math.PI / 180)) * Math.cos(y2 * (Math.PI / 180)) *
                  Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    };

    // ── Helper: Get total WAC of campaign members (RAC deducted) ────────────────
    const getCampaignTotalWac = async (campaignId: string): Promise<string> => {
        const members = await prisma.campaignMember.findMany({
            where: { campaignId },
            include: { user: { include: { wac: true, rac: true } } }
        });

        let total = new Prisma.Decimal(0);
        for (const member of members) {
            const wacBalance = member.user.wac?.wacBalance ?? new Prisma.Decimal(0);
            const racValue = member.user.rac?.racBalance;
            const racBalance = racValue ? new Prisma.Decimal(racValue.toString()) : new Prisma.Decimal(0);
            // Net WAC = WAC - RAC (RAC is borrowed, deducted from WAC)
            const net = wacBalance.minus(racBalance);
            if (net.greaterThan(0)) {
                total = total.plus(net);
            }
        }
        return total.toFixed(6);
    };

    // ── List Nearby Campaigns (by user location) ───────────────────────────────
    fastify.get('/nearby', async (request, reply) => {
        try {
            const user = (request as any).user;
            const userIcon = await prisma.icon.findUnique({ where: { userId: user.id } });
            if (!userIcon) {
                return reply.send({ success: true, campaigns: [] });
            }

            const userX = userIcon.lastKnownX;
            const userY = userIcon.lastKnownY;
            const radiusKm = 100; // 100km radius

            // Get all active campaigns
            const campaigns = await prisma.campaign.findMany({
                where: { isActive: true },
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    members: { include: { user: { include: { icon: true } } } },
                    _count: { select: { polls: true } }
                }
            });

            // Filter by distance and sort
            const nearby = campaigns
                .filter(c => {
                    // Check if any member is within radius
                    return c.members.some(m => {
                        const icon = m.user.icon;
                        if (!icon) return false;
                        const distance = calcDistance(userX, userY, icon.lastKnownX, icon.lastKnownY);
                        return distance <= radiusKm;
                    });
                })
                .slice(0, 20);

            // Enrich with total WAC
            const enriched = await Promise.all(nearby.map(async c => ({
                ...c,
                totalWac: await getCampaignTotalWac(c.id),
                memberCount: c.members.length,
                pollCount: c._count.polls
            })));

            return reply.send({ success: true, campaigns: enriched });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch nearby campaigns' });
        }
    });

    // ── List Popular Campaigns (by member count) ───────────────────────────────
    fastify.get('/popular', async (_request, reply) => {
        try {
            const campaigns = await prisma.campaign.findMany({
                where: { isActive: true },
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    members: { include: { user: { include: { wac: true, rac: true } } } },
                    _count: { select: { polls: true } }
                },
                orderBy: [{ members: { _count: 'desc' } }, { createdAt: 'desc' }],
                take: 20
            });

            // Enrich with total WAC
            const enriched = await Promise.all(campaigns.map(async c => ({
                ...c,
                totalWac: await getCampaignTotalWac(c.id),
                memberCount: c.members.length,
                pollCount: c._count.polls
            })));

            return reply.send({ success: true, campaigns: enriched });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch popular campaigns' });
        }
    });

    // ── List Trending Campaigns (by poll reactions) ───────────────────────────
    fastify.get('/trending', async (_request, reply) => {
        try {
            const campaigns = await prisma.campaign.findMany({
                where: { isActive: true },
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    members: { include: { user: { include: { wac: true, rac: true } } } },
                    polls: { include: { _count: { select: { votes: true } } } },
                    _count: { select: { polls: true } }
                }
            });

            // Filter and sort by total poll votes
            const trending = campaigns
                .map(c => ({
                    campaign: c,
                    totalVotes: c.polls.reduce((sum, p) => sum + p._count.votes, 0)
                }))
                .sort((a, b) => b.totalVotes - a.totalVotes)
                .slice(0, 20)
                .map(item => item.campaign);

            // Enrich with total WAC
            const enriched = await Promise.all(trending.map(async c => ({
                ...c,
                totalWac: await getCampaignTotalWac(c.id),
                memberCount: c.members.length,
                pollCount: c._count.polls
            })));

            return reply.send({ success: true, campaigns: enriched });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch trending campaigns' });
        }
    });
}
