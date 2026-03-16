import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import jwt from 'jsonwebtoken';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

export async function profileRoutes(fastify: FastifyInstance) {

    fastify.addHook('preHandler', async (request, reply) => {
        const authHeader = request.headers.authorization;
        if (!authHeader) return reply.code(401).send({ error: 'Missing token' });

        try {
            const token = authHeader.split(' ')[1];
            // @ts-ignore
            const decoded = jwt.verify(token, JWT_SECRET) as any;
            (request as any).userId = decoded.userId;
        } catch (err) {
            return reply.code(401).send({ error: 'Invalid token' });
        }
    });

    fastify.put('/', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const { avatarUrl, slogan, description, displayName } = request.body as any;

            // Validate displayName
            if (displayName !== undefined) {
                if (typeof displayName !== 'string' || displayName.length > 16 || !/^[a-zA-ZçÇğĞıİöÖşŞüÜ\s]+$/.test(displayName)) {
                    return reply.code(400).send({ error: 'Gecersiz isim. Sadece harf ve bosluk, en fazla 16 karakter.' });
                }
            }

            // Optional updates
            const userUpdate: any = {};
            if (avatarUrl !== undefined) userUpdate.avatarUrl = avatarUrl;
            if (slogan !== undefined) userUpdate.slogan = slogan;
            if (description !== undefined) userUpdate.description = description;
            if (displayName !== undefined) userUpdate.displayName = displayName;

            if (Object.keys(userUpdate).length > 0) {
                await prisma.user.update({
                    where: { id: userId },
                    data: userUpdate
                });
            }

            // Sync visual overrides if they own an icon (iconSize is no longer validated against tokens)
            if ((request.body as any).iconAlignment !== undefined || slogan !== undefined) {
                await prisma.icon.updateMany({
                    where: { userId },
                    data: {
                        ...((request.body as any).iconAlignment !== undefined ? { exploreMode: (request.body as any).iconAlignment } : {}),
                        ...(slogan !== undefined ? { slogan: slogan } : {}), // Keep map icon slogan in sync
                    }
                });
            }

            return reply.send({ success: true });
        } catch (err: any) {
            fastify.log.error(`Profile update failed: ${err}`);
            return reply.code(500).send({ error: 'Failed to update profile' });
        }
    });

    fastify.get('/me', async (request, reply) => {
        try {
            const userId = (request as any).userId;

            const user = await prisma.user.findUnique({
                where: { id: userId },
                select: {
                    id: true,
                    displayName: true,
                    avatarUrl: true,
                    slogan: true,
                    description: true,
                }
            });

            const userWac = await prisma.userWac.findUnique({
                where: { userId },
                select: { wacBalance: true, isActive: true }
            });

            if (!userWac) return reply.send({ wacBalance: '0.000000', isActive: false });

            return reply.send({
                ...user,
                wacBalance: userWac.wacBalance.toFixed(6),
                isActive: userWac.isActive,
            });
        } catch (err) {
            return reply.code(500).send({ error: 'Failed' });
        }
    });

    fastify.get('/:id', async (request, reply) => {
        try {
            const { id } = request.params as any;

            const profile = await prisma.user.findUnique({
                where: { id },
                select: {
                    id: true,
                    displayName: true,
                    avatarUrl: true,
                    slogan: true,
                    description: true,
                    icon: { select: { lastKnownX: true, lastKnownY: true, auraRadius: true, exploreMode: true } },
                    campaignMemberships: {
                        select: {
                            campaignId: true,
                            stakedWac: true,
                            joinedAt: true,
                            campaign: {
                                select: { id: true, title: true, slogan: true, isActive: true }
                            }
                        },
                        where: {
                            campaign: { isActive: true }
                        }
                    }
                }
            });

            if (!profile) return reply.code(404).send({ error: 'Profile not found' });

            // Count followers and following separately
            const [followerCount, followingCount] = await Promise.all([
                prisma.follow.count({ where: { followingId: id, status: 'APPROVED' } }),
                prisma.follow.count({ where: { followerId: id, status: 'APPROVED' } }),
            ]);

            return reply.send({
                ...profile,
                followerCount,
                followingCount
            });

        } catch (err: any) {
            return reply.code(500).send({ error: 'Failed to fetch public profile' });
        }
    });

    fastify.get('/:id/daily-rewards', async (request, reply) => {
        const { id } = request.params as any;

        // Get all campaigns the user is a member of
        const memberships = await prisma.campaignMember.findMany({
            where: { userId: id },
            include: {
                campaign: {
                    select: { id: true, title: true, slogan: true, totalWacStaked: true },
                },
            },
        });

        // Calculate total system staked for daily pool
        const systemTotal = await prisma.campaign.aggregate({
            _sum: { totalWacStaked: true },
        });
        const totalSystemStaked = Number(systemTotal._sum.totalWacStaked || 0);

        if (totalSystemStaked === 0) {
            return { campaigns: memberships.map(m => ({
                campaignId: m.campaign.id,
                title: m.campaign.title,
                slogan: m.campaign.slogan,
                dailyReward: '0',
            })) };
        }

        // Daily pool = sqrt(totalSystemStaked) * 2
        const dailyPool = Math.sqrt(totalSystemStaked) * 2;

        const campaigns = memberships.map(m => {
            const campaignStaked = Number(m.campaign.totalWacStaked);
            const userStaked = Number(m.stakedWac);
            const campaignShare = (campaignStaked / totalSystemStaked) * dailyPool;
            const userShare = campaignStaked > 0 ? (userStaked / campaignStaked) * campaignShare : 0;

            // Format: floor at 6 decimals, remove trailing zeros
            const floored = Math.floor(userShare * 1000000) / 1000000;
            let formatted = floored.toFixed(6).replace(/\.?0+$/, '');

            return {
                campaignId: m.campaign.id,
                title: m.campaign.title,
                slogan: m.campaign.slogan,
                dailyReward: formatted,
            };
        });

        return { campaigns };
    });
}
