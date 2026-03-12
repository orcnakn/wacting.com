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

            // Sync visual overrides if they own an icon (iconSize is no longer validated against tokens)
            if (body.iconAlignment !== undefined || body.slogan !== undefined) {
                await prisma.icon.updateMany({
                    where: { userId },
                    data: {
                        ...(body.iconAlignment !== undefined ? { exploreMode: body.iconAlignment } : {}),
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

            const userWac = await prisma.userWac.findUnique({
                where: { userId },
                select: { wacBalance: true, isActive: true }
            });

            if (!userWac) return reply.send({ wacBalance: '0.000000', isActive: false });

            return reply.send({
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
                    avatarUrl: true,
                    slogan: true,
                    description: true,
                    icon: { select: { lastKnownX: true, lastKnownY: true, auraRadius: true, exploreMode: true } }
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
}
