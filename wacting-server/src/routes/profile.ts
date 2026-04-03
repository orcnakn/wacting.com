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
            const { avatarUrl, slogan, description, displayName,
                    twitterUrl, facebookUrl, instagramUrl, tiktokUrl, linkedinUrl } = request.body as any;

            if (displayName !== undefined) {
                if (typeof displayName !== 'string' || displayName.length > 16 || !/^[a-zA-ZçÇğĞıİöÖşŞüÜ\s]+$/.test(displayName)) {
                    return reply.code(400).send({ error: 'Gecersiz isim. Sadece harf ve bosluk, en fazla 16 karakter.' });
                }
            }

            const userUpdate: any = {};
            if (avatarUrl !== undefined) userUpdate.avatarUrl = avatarUrl;
            if (slogan !== undefined) userUpdate.slogan = slogan;
            if (description !== undefined) userUpdate.description = description;
            if (displayName !== undefined) userUpdate.displayName = displayName;
            // Auto-generate full URLs from usernames if no http prefix
            const autoUrl = (val: string | undefined, baseUrl: string) => {
                if (val === undefined) return undefined;
                if (!val || val.trim() === '') return val;
                if (val.startsWith('http')) return val;
                return `${baseUrl}${val.replace('@', '')}`;
            };
            if (twitterUrl !== undefined) userUpdate.twitterUrl = autoUrl(twitterUrl, 'https://x.com/');
            if (facebookUrl !== undefined) userUpdate.facebookUrl = autoUrl(facebookUrl, 'https://facebook.com/');
            if (instagramUrl !== undefined) userUpdate.instagramUrl = autoUrl(instagramUrl, 'https://instagram.com/');
            if (tiktokUrl !== undefined) userUpdate.tiktokUrl = autoUrl(tiktokUrl, 'https://tiktok.com/@');
            if (linkedinUrl !== undefined) userUpdate.linkedinUrl = autoUrl(linkedinUrl, 'https://linkedin.com/in/');

            // Update socialLinksOrder when any social URL changes
            const socialFields = ['twitterUrl', 'facebookUrl', 'instagramUrl', 'tiktokUrl', 'linkedinUrl'];
            const hasSocialUpdate = socialFields.some(f => (request.body as any)[f] !== undefined);
            if (hasSocialUpdate) {
                const currentUser = await prisma.user.findUnique({
                    where: { id: userId },
                    select: { socialLinksOrder: true, twitterUrl: true, facebookUrl: true, instagramUrl: true, tiktokUrl: true, linkedinUrl: true },
                });
                const currentOrder: string[] = currentUser?.socialLinksOrder ? JSON.parse(currentUser.socialLinksOrder) : [];
                const platformMap: Record<string, string> = {
                    twitterUrl: 'twitter', facebookUrl: 'facebook', instagramUrl: 'instagram',
                    tiktokUrl: 'tiktok', linkedinUrl: 'linkedin',
                };
                for (const field of socialFields) {
                    const val = (request.body as any)[field];
                    const platform = platformMap[field] ?? field;
                    if (val && typeof val === 'string' && val.trim() !== '') {
                        if (!currentOrder.includes(platform)) currentOrder.push(platform);
                    } else if (val === '' || val === null) {
                        const idx = currentOrder.indexOf(platform);
                        if (idx !== -1) currentOrder.splice(idx, 1);
                    }
                }
                userUpdate.socialLinksOrder = JSON.stringify(currentOrder);
            }

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

    // PUT /api/profile/social-followers — Update follower count for a platform
    fastify.put('/social-followers', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const { platform, followerCount } = request.body as any;
            const validPlatforms = ['instagram', 'twitter', 'facebook', 'tiktok', 'linkedin'];
            if (!validPlatforms.includes(platform) || typeof followerCount !== 'number') {
                return reply.code(400).send({ error: 'Invalid platform or follower count' });
            }
            const fieldMap: Record<string, string> = {
                instagram: 'instagramFollowers', twitter: 'twitterFollowers',
                facebook: 'facebookFollowers', tiktok: 'tiktokFollowers', linkedin: 'linkedinFollowers',
            };
            await prisma.user.update({
                where: { id: userId },
                data: { [fieldMap[platform]!]: followerCount },
            });
            return reply.send({ success: true });
        } catch (err: any) {
            fastify.log.error(`Social followers update failed: ${err}`);
            return reply.code(500).send({ error: 'Failed to update follower count' });
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
                    cachedProfileLevel: true,
                    cachedFollowerLevel: true,
                    cachedAgeLevel: true,
                    cachedWacLevel: true,
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
                profileLevel: user?.cachedProfileLevel ?? 1,
                followerLevel: user?.cachedFollowerLevel ?? 0,
                ageLevel: user?.cachedAgeLevel ?? 1,
                wacLevel: user?.cachedWacLevel ?? 0,
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
                    twitterUrl: true,
                    facebookUrl: true,
                    instagramUrl: true,
                    tiktokUrl: true,
                    linkedinUrl: true,
                    socialLinksOrder: true,
                    walletId: true,
                    cachedProfileLevel: true,
                    cachedFollowerLevel: true,
                    cachedAgeLevel: true,
                    cachedWacLevel: true,
                    instagramFollowers: true,
                    twitterFollowers: true,
                    facebookFollowers: true,
                    tiktokFollowers: true,
                    linkedinFollowers: true,
                    isPrivate: true,
                    icon: { select: { lastKnownX: true, lastKnownY: true, exploreMode: true } },
                    campaignMemberships: {
                        select: {
                            campaignId: true,
                            stakedWac: true,
                            joinedAt: true,
                            campaign: {
                                select: { id: true, title: true, slogan: true, isActive: true, cachedLevel: true, stanceType: true }
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

            const viewerId = (request as any).userId;
            let isFollowedByViewer = false;
            if (viewerId && viewerId !== id) {
                const followRecord = await prisma.follow.findUnique({
                    where: { followerId_followingId: { followerId: id, followingId: viewerId } },
                });
                isFollowedByViewer = followRecord?.status === 'APPROVED';
            }

            return reply.send({
                ...profile,
                followerCount,
                followingCount,
                isFollowedByViewer,
                profileLevel: profile.cachedProfileLevel,
                followerLevel: profile.cachedFollowerLevel,
                ageLevel: profile.cachedAgeLevel,
                wacLevel: profile.cachedWacLevel,
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

    fastify.get('/wallet/history', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const { page = '1', limit = '20', type } = request.query as any;
            const pageNum = Math.max(1, Number(page));
            const limitNum = Math.min(50, Math.max(1, Number(limit)));
            const skip = (pageNum - 1) * limitNum;

            const where: any = { userId };
            if (type) where.type = type;

            const [transactions, total] = await Promise.all([
                prisma.transaction.findMany({
                    where,
                    orderBy: { createdAt: 'desc' },
                    skip,
                    take: limitNum,
                    select: {
                        id: true, amount: true, type: true, note: true,
                        createdAt: true, campaignId: true, walletId: true, toWalletId: true,
                    },
                }),
                prisma.transaction.count({ where }),
            ]);

            return reply.send({
                page: pageNum,
                limit: limitNum,
                total,
                transactions: transactions.map(t => ({
                    ...t,
                    amount: t.amount.toFixed(6),
                })),
            });
        } catch (err: any) {
            return reply.code(500).send({ error: 'Failed to fetch wallet history' });
        }
    });
}
