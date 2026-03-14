import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

const createNoteSchema = z.object({
    content: z.string().min(3).max(2000),
    category: z.enum(['BUG', 'SUGGESTION', 'FEEDBACK']),
});

export async function devNotesRoutes(fastify: FastifyInstance) {

    // JWT auth hook
    fastify.addHook('preHandler', async (request, reply) => {
        const authHeader = request.headers.authorization;
        if (!authHeader) return reply.code(401).send({ error: 'Missing token' });

        try {
            const token = authHeader.split(' ')[1] ?? '';
            const decoded = jwt.verify(token, JWT_SECRET as string) as any;
            (request as any).userId = decoded.userId;
        } catch {
            return reply.code(401).send({ error: 'Invalid token' });
        }
    });

    // POST / — Create developer note
    fastify.post('/', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const { content, category } = createNoteSchema.parse(request.body);

            const note = await prisma.devNote.create({
                data: { userId, content, category },
            });

            return reply.code(201).send({ success: true, note });
        } catch (err: any) {
            fastify.log.error(`DevNote creation failed: ${err}`);
            return reply.code(400).send({ error: err.message || 'Invalid data' });
        }
    });

    // GET /mine — List my notes (paginated)
    fastify.get('/mine', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const query = request.query as { page?: string; limit?: string };
            const page = Math.max(1, Number(query.page || '1'));
            const limit = Math.min(50, Math.max(1, Number(query.limit || '20')));
            const skip = (page - 1) * limit;

            const [notes, total] = await Promise.all([
                prisma.devNote.findMany({
                    where: { userId },
                    orderBy: { createdAt: 'desc' },
                    skip,
                    take: limit,
                }),
                prisma.devNote.count({ where: { userId } }),
            ]);

            return reply.send({ page, limit, total, notes });
        } catch (err: any) {
            return reply.code(500).send({ error: 'Failed to fetch notes' });
        }
    });
}
