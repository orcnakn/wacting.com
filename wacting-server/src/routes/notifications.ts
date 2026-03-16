import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { authenticateToken } from '../middleware/auth.js';

const prisma = new PrismaClient();

export default async function notificationRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticateToken);

  // GET /api/notifications - paginated list
  fastify.get('/', async (request, reply) => {
    const userId = (request as any).user?.id;
    const { page = 1, limit = 20 } = request.query as any;
    const skip = (Number(page) - 1) * Number(limit);

    const [notifications, total] = await Promise.all([
      prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: Number(limit),
      }),
      prisma.notification.count({ where: { userId } }),
    ]);

    return { notifications, total, page: Number(page), limit: Number(limit) };
  });

  // GET /api/notifications/unread-count
  fastify.get('/unread-count', async (request, reply) => {
    const userId = (request as any).user?.id;
    const count = await prisma.notification.count({
      where: { userId, read: false },
    });
    return { count };
  });

  // PUT /api/notifications/:id/read
  fastify.put('/:id/read', async (request, reply) => {
    const userId = (request as any).user?.id;
    const { id } = request.params as any;
    await prisma.notification.updateMany({
      where: { id, userId },
      data: { read: true },
    });
    return { success: true };
  });

  // PUT /api/notifications/read-all
  fastify.put('/read-all', async (request, reply) => {
    const userId = (request as any).user?.id;
    await prisma.notification.updateMany({
      where: { userId, read: false },
      data: { read: true },
    });
    return { success: true };
  });
}
