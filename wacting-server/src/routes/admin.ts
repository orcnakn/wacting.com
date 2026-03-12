import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import jwt, { Secret } from 'jsonwebtoken';

const prisma = new PrismaClient();
const JWT_SECRET: Secret = process.env.JWT_SECRET || 'super_secret_dev_key';

export async function adminRoutes(fastify: FastifyInstance) {

    // Middleware to verify Admin JWT presence
    fastify.addHook('preHandler', async (request, reply) => {
        const authHeader = request.headers.authorization;
        if (!authHeader) {
            return reply.code(401).send({ error: 'Missing token' });
        }

        try {
            const token = authHeader.split(' ')[1];
            // @ts-ignore - JWT type mismatch library resolution
            const decoded = jwt.verify(token, JWT_SECRET) as any;

            // Check if user has ADMIN role
            const user = await prisma.user.findUnique({ where: { id: decoded.userId } });
            if (!user || user.role !== 'ADMIN') {
                return reply.code(403).send({ error: 'Forbidden: Admin access required.' });
            }

            (request as any).adminUser = user;
        } catch (err) {
            return reply.code(401).send({ error: 'Invalid token' });
        }
    });

    // 1. Get Global Telemetry & Traffic
    fastify.get('/admin/stats', async (request, reply) => {
        const totalUsers = await prisma.user.count();
        const activeUsers = await prisma.user.count({ where: { status: 'ACTIVE' } });
        const bannedUsers = await prisma.user.count({ where: { status: 'BANNED' } });

        // Count total WAC deposited (sum from treasury + active balances)
        const wacCount = await prisma.userWac.count({ where: { isActive: true } });

        return reply.send({
            totalUsers,
            activeUsers,
            bannedUsers,
            activeWacUsers: wacCount
        });
    });

    // 2. View User Reports
    fastify.get('/admin/reports', async (request, reply) => {
        const reports = await prisma.report.findMany({
            include: {
                reporter: { select: { id: true, email: true } },
                reported: { select: { id: true, email: true, status: true } }
            },
            orderBy: { createdAt: 'desc' },
            take: 50
        });

        return reply.send({ reports });
    });

    // 3. Ban / Unban User
    fastify.post('/admin/ban', async (request, reply) => {
        const { targetUserId, action } = request.body as any;

        if (!['BAN', 'UNBAN'].includes(action)) {
            return reply.code(400).send({ error: 'Invalid action. Use BAN or UNBAN' });
        }

        const newStatus = action === 'BAN' ? 'BANNED' : 'ACTIVE';

        const updated = await prisma.user.update({
            where: { id: targetUserId },
            data: { status: newStatus }
        });

        fastify.log.info(`Admin action: ${action} on User: ${targetUserId}`);
        return reply.send({ success: true, newStatus: updated.status });
    });
}
