import { FastifyInstance } from 'fastify';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

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

    // Token delegation has been replaced by the WAC economy system.
    fastify.post('/economy/delegate', async (_request, reply) => {
        return reply.code(410).send({ error: 'Token delegation is no longer supported. Use /wac/deposit instead.' });
    });

    fastify.post('/economy/undelegate', async (_request, reply) => {
        return reply.code(410).send({ error: 'Token delegation is no longer supported. Use /wac/exit instead.' });
    });
}
