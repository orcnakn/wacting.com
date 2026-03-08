import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import jwt from 'jsonwebtoken';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

const delegateSchema = z.object({
    targetUserId: z.string(),
    amount: z.number().positive()
});

export async function economyRoutes(fastify: FastifyInstance) {

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

    fastify.post('/economy/delegate', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const { targetUserId, amount } = delegateSchema.parse(request.body);

            if (userId === targetUserId) {
                return reply.code(400).send({ error: "Cannot delegate to yourself" });
            }

            const me = await prisma.user.findUnique({ where: { id: userId } });
            // We assume Base Tokens are kept track of.
            // A user can delegate tokens down to 1 remaining token so they don't vanish from the map.
            if (!me || Number(me.tokens) <= amount) {
                return reply.code(400).send({ error: "Insufficient tokens to delegate, must keep at least 1." });
            }

            const delegation = await prisma.delegation.upsert({
                where: {
                    fromUserId_toUserId: {
                        fromUserId: userId,
                        toUserId: targetUserId
                    }
                },
                update: {
                    amount: { increment: amount }
                },
                create: {
                    fromUserId: userId,
                    toUserId: targetUserId,
                    amount: amount
                }
            });

            fastify.log.info(`User ${userId} delegated ${amount} tokens to ${targetUserId}`);
            return reply.send({ success: true, delegation });
        } catch (err: any) {
            fastify.log.error(`Delegation failed: ${err}`);
            return reply.code(400).send({ error: 'Invalid delegation payload' });
        }
    });

    fastify.post('/economy/undelegate', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const { targetUserId } = z.object({ targetUserId: z.string() }).parse(request.body);

            await prisma.delegation.deleteMany({
                where: {
                    fromUserId: userId,
                    toUserId: targetUserId
                }
            });

            fastify.log.info(`User ${userId} revoked delegation from ${targetUserId}`);
            return reply.send({ success: true });
        } catch (err: any) {
            fastify.log.error(`Revoke failed: ${err}`);
            return reply.code(400).send({ error: 'Invalid revoke payload' });
        }
    });
}
