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
            const body: any = request.body;

            // Optional updates
            const userUpdate: any = {};
            if (body.avatarUrl !== undefined) userUpdate.avatarUrl = body.avatarUrl;
            if (body.slogan !== undefined) userUpdate.slogan = body.slogan;
            if (body.description !== undefined) userUpdate.description = body.description;

            if (Object.keys(userUpdate).length > 0) {
                await prisma.user.update({
                    where: { id: userId },
                    data: userUpdate
                });
            }

            // Sync visual overrides if they own an icon
            if (body.iconSize !== undefined || body.iconAlignment !== undefined) {
                const user = await prisma.user.findUnique({ where: { id: userId } });

                // Security check: Size slider shouldn't exceed token wallet divided by some factor (e.g., 100)
                // For demo purposes, we clamp it to what they asked for, but we should validate
                const maxVisualSize = Math.max(1, Number(user?.tokens || 0) / 100);
                let safeSize = body.iconSize;

                if (safeSize > maxVisualSize) safeSize = maxVisualSize;

                await prisma.icon.updateMany({
                    where: { userId },
                    data: {
                        ...(body.iconSize !== undefined ? { visualSize: safeSize } : {}),
                        ...(body.iconAlignment !== undefined ? { visualAlign: body.iconAlignment } : {}),
                        ...(body.slogan !== undefined ? { slogan: body.slogan } : {}), // Keep map icon slogan in sync
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
                select: { tokens: true }
            });

            if (!user) return reply.code(404).send({ error: 'Not found' });

            // Calculate active dividends this user currently holds
            // (Dividends are already in the `tokens` balance, but this lets the UI show how much of it is passive)
            const activeFollows = await prisma.follow.findMany({
                where: { followerId: userId, status: 'APPROVED' },
                select: { earnedDividends: true }
            });

            const totalPassiveDividends = activeFollows.reduce((acc, f) => acc + f.earnedDividends, 0n);

            return reply.send({
                tokens: user.tokens.toString(),
                passiveDividends: totalPassiveDividends.toString(),
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
                    avatarUrl: true,
                    slogan: true,
                    description: true,
                    followers: { select: { followerId: true } },
                    following: { select: { followingId: true } },
                    icon: { select: { visualSize: true, visualAlign: true, lastKnownX: true, lastKnownY: true } }
                }
            });

            if (!profile) return reply.code(404).send({ error: 'Profile not found' });

            return reply.send({
                ...profile,
                followerCount: profile.followers.length,
                followingCount: profile.following.length
            });

        } catch (err: any) {
            return reply.code(500).send({ error: 'Failed to fetch public profile' });
        }
    });
}
