import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import jwt, { Secret } from 'jsonwebtoken';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const prisma = new PrismaClient();
const JWT_SECRET: Secret = process.env.JWT_SECRET || 'super_secret_dev_key';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export async function adminRoutes(fastify: FastifyInstance) {

    // ── Admin Auth Middleware ─────────────────────────────────────────────────
    fastify.addHook('preHandler', async (request, reply) => {
        // Allow GET /admin/panel (HTML page) without token
        if (request.url === '/admin/panel' || request.url === '/admin/panel/') return;

        const authHeader = request.headers.authorization;
        if (!authHeader) {
            return reply.code(401).send({ error: 'Missing token' });
        }

        try {
            const token = authHeader.split(' ')[1] ?? '';
            const decoded = jwt.verify(token, JWT_SECRET) as any;
            const user = await prisma.user.findUnique({ where: { id: decoded.userId } });
            if (!user || user.role !== 'ADMIN') {
                return reply.code(403).send({ error: 'Forbidden: Admin access required.' });
            }
            (request as any).adminUser = user;
        } catch (err) {
            return reply.code(401).send({ error: 'Invalid token' });
        }
    });

    // ── Admin Panel HTML ──────────────────────────────────────────────────────
    fastify.get('/admin/panel', async (_request, reply) => {
        const htmlPath = path.join(__dirname, '../public/admin.html');
        if (fs.existsSync(htmlPath)) {
            const html = fs.readFileSync(htmlPath, 'utf-8');
            return reply.type('text/html').send(html);
        }
        return reply.type('text/html').send('<h2>Admin panel dosyası bulunamadı.</h2>');
    });

    // ── GET /admin/stats ──────────────────────────────────────────────────────
    fastify.get('/admin/stats', async (_request, reply) => {
        const [
            totalUsers,
            verifiedUsers,
            unverifiedUsers,
            bannedUsers,
            activeWacUsers,
            totalCampaigns,
            activeCampaigns,
            todayUsers,
            weekUsers,
        ] = await Promise.all([
            prisma.user.count(),
            prisma.user.count({ where: { emailVerified: true } }),
            prisma.user.count({ where: { emailVerified: false, email: { not: null } } }),
            prisma.user.count({ where: { status: 'BANNED' } }),
            prisma.userWac.count({ where: { isActive: true } }),
            prisma.campaign.count(),
            prisma.campaign.count({ where: { isActive: true } }),
            prisma.user.count({
                where: { createdAt: { gte: new Date(Date.now() - 86_400_000) } }
            }),
            prisma.user.count({
                where: { createdAt: { gte: new Date(Date.now() - 7 * 86_400_000) } }
            }),
        ]);

        return reply.send({
            totalUsers,
            verifiedUsers,
            unverifiedUsers,
            bannedUsers,
            activeWacUsers,
            totalCampaigns,
            activeCampaigns,
            todayUsers,
            weekUsers,
        });
    });

    // ── GET /admin/users ──────────────────────────────────────────────────────
    fastify.get('/admin/users', async (request, reply) => {
        const query = request.query as {
            page?: string;
            limit?: string;
            search?: string;
            status?: string;
        };

        const page  = Math.max(1, Number(query.page  || '1'));
        const limit = Math.min(100, Math.max(1, Number(query.limit || '20')));
        const skip  = (page - 1) * limit;

        const where: any = {};
        if (query.status) where.status = query.status;
        if (query.search) {
            where.OR = [
                { email:  { contains: query.search, mode: 'insensitive' } },
                { slogan: { contains: query.search, mode: 'insensitive' } },
            ];
        }

        const [users, total] = await Promise.all([
            prisma.user.findMany({
                where,
                skip,
                take: limit,
                orderBy: { createdAt: 'desc' },
                select: {
                    id: true,
                    email: true,
                    slogan: true,
                    role: true,
                    status: true,
                    emailVerified: true,
                    createdAt: true,
                    wac: { select: { wacBalance: true, isActive: true } },
                    _count: { select: { campaigns: true } },
                },
            }),
            prisma.user.count({ where }),
        ]);

        return reply.send({
            page,
            limit,
            total,
            totalPages: Math.ceil(total / limit),
            users,
        });
    });

    // ── GET /admin/users/:id ──────────────────────────────────────────────────
    fastify.get('/admin/users/:id', async (request, reply) => {
        const { id } = request.params as { id: string };

        const user = await prisma.user.findUnique({
            where: { id },
            include: {
                wac: true,
                rac: true,
                campaigns: { select: { id: true, title: true, isActive: true, createdAt: true } },
                transactions: { orderBy: { createdAt: 'desc' }, take: 20 },
                _count: { select: { campaigns: true, followers: true, following: true } },
            },
        });

        if (!user) return reply.code(404).send({ error: 'User not found.' });
        return reply.send({ user });
    });

    // ── POST /admin/ban ───────────────────────────────────────────────────────
    fastify.post('/admin/ban', async (request, reply) => {
        const { targetUserId, action } = request.body as any;

        if (!['BAN', 'UNBAN'].includes(action)) {
            return reply.code(400).send({ error: 'Invalid action. Use BAN or UNBAN' });
        }

        const updated = await prisma.user.update({
            where: { id: targetUserId },
            data: { status: action === 'BAN' ? 'BANNED' : 'ACTIVE' },
        });

        fastify.log.info(`Admin action: ${action} on User: ${targetUserId}`);
        return reply.send({ success: true, newStatus: updated.status });
    });

    // ── POST /admin/verify-email ──────────────────────────────────────────────
    fastify.post('/admin/verify-email', async (request, reply) => {
        const { userId } = request.body as { userId: string };

        await prisma.user.update({
            where: { id: userId },
            data: { emailVerified: true, emailVerifyToken: null },
        });

        return reply.send({ success: true, message: 'Email manually verified.' });
    });

    // ── GET /admin/reports ────────────────────────────────────────────────────
    fastify.get('/admin/reports', async (_request, reply) => {
        const reports = await prisma.report.findMany({
            include: {
                reporter: { select: { id: true, email: true } },
                reported:  { select: { id: true, email: true, status: true } },
            },
            orderBy: { createdAt: 'desc' },
            take: 50,
        });

        return reply.send({ reports });
    });
}
