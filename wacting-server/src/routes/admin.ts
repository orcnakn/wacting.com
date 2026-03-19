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
            botUsers,
            devNotesTotal,
            devNotesUnread,
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
            prisma.user.count({ where: { isBot: true } }),
            prisma.devNote.count(),
            prisma.devNote.count({ where: { isRead: false } }),
        ]);

        // WAC/RAC circulation totals + active sessions
        const [wacAgg, racAgg, activeSessions] = await Promise.all([
            prisma.userWac.aggregate({ _sum: { wacBalance: true } }),
            prisma.userRac.aggregate({ _sum: { racBalance: true } }),
            prisma.loginSession.count({ where: { logoutAt: null } }),
        ]);
        const totalWacCirculation = wacAgg._sum.wacBalance?.toString() ?? '0';
        const totalRacCirculation = racAgg._sum.racBalance?.toString() ?? '0';

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
            botUsers,
            devNotesTotal,
            devNotesUnread,
            totalWacCirculation,
            totalRacCirculation,
            activeSessions,
        });
    });

    // ── GET /admin/users ──────────────────────────────────────────────────────
    fastify.get('/admin/users', async (request, reply) => {
        const query = request.query as {
            page?: string;
            limit?: string;
            search?: string;
            status?: string;
            createdAfter?: string;
            isBot?: string;
            hasActiveSession?: string;
        };

        const page  = Math.max(1, Number(query.page  || '1'));
        const limit = Math.min(100, Math.max(1, Number(query.limit || '20')));
        const skip  = (page - 1) * limit;

        const where: any = {};
        if (query.status) where.status = query.status;
        if ((query as any).emailVerified !== undefined && (query as any).emailVerified !== '') {
            where.emailVerified = (query as any).emailVerified === 'true';
        }
        if (query.isBot !== undefined && query.isBot !== '') {
            where.isBot = query.isBot === 'true';
        }
        if (query.createdAfter) {
            where.createdAt = { gte: new Date(query.createdAfter) };
        }
        if (query.hasActiveSession === 'true') {
            where.loginSessions = { some: { logoutAt: null } };
        }
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
                    isBot: true,
                    createdAt: true,
                    wac: { select: { wacBalance: true, isActive: true } },
                    rac: { select: { racBalance: true } },
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
                campaignMemberships: {
                    include: {
                        campaign: { select: { id: true, title: true, isActive: true, stanceType: true, categoryType: true, totalWacStaked: true } },
                    },
                    orderBy: { joinedAt: 'desc' },
                },
                transactions: { orderBy: { createdAt: 'desc' }, take: 20 },
                loginSessions: { orderBy: { loginAt: 'desc' }, take: 20 },
                _count: { select: { campaigns: true, followers: true, following: true } },
            },
        });

        if (!user) return reply.code(404).send({ error: 'User not found.' });

        // Calculate total time spent
        const allSessions = await prisma.loginSession.findMany({
            where: { userId: id },
            select: { duration: true },
        });
        const totalTimeSpent = allSessions.reduce((sum, s) => sum + (s.duration || 0), 0);

        return reply.send({ user, totalTimeSpent });
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

    // ── POST /admin/notify ────────────────────────────────────────────────────
    fastify.post('/admin/notify', async (request, reply) => {
        const { userId, title, message } = request.body as { userId: string; title: string; message: string };
        if (!userId || !title || !message) {
            return reply.code(400).send({ error: 'userId, title and message are required.' });
        }

        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { email: true, slogan: true },
        });
        if (!user) return reply.code(404).send({ error: 'User not found.' });

        await prisma.notification.create({
            data: { userId, type: 'SYSTEM', title, message },
        });

        fastify.log.info(`[Admin] Notification sent to user ${userId}: ${title}`);
        return reply.send({ success: true });
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

    // ── GET /admin/dev-notes ────────────────────────────────────────────────
    fastify.get('/admin/dev-notes', async (request, reply) => {
        const query = request.query as {
            page?: string;
            limit?: string;
            category?: string;
            userId?: string;
            isRead?: string;
        };

        const page  = Math.max(1, Number(query.page || '1'));
        const limit = Math.min(100, Math.max(1, Number(query.limit || '20')));
        const skip  = (page - 1) * limit;

        const where: any = {};
        if (query.category) where.category = query.category;
        if (query.userId) where.userId = query.userId;
        if (query.isRead !== undefined && query.isRead !== '') {
            where.isRead = query.isRead === 'true';
        }

        const [notes, total] = await Promise.all([
            prisma.devNote.findMany({
                where,
                skip,
                take: limit,
                orderBy: { createdAt: 'desc' },
                include: {
                    user: { select: { id: true, email: true, slogan: true, isBot: true } },
                },
            }),
            prisma.devNote.count({ where }),
        ]);

        return reply.send({
            page,
            limit,
            total,
            totalPages: Math.ceil(total / limit),
            notes,
        });
    });

    // ── POST /admin/dev-notes/:id/read ──────────────────────────────────────
    fastify.post('/admin/dev-notes/:id/read', async (request, reply) => {
        const { id } = request.params as { id: string };

        await prisma.devNote.update({
            where: { id },
            data: { isRead: true },
        });

        return reply.send({ success: true });
    });

    // ── GET /admin/campaigns ────────────────────────────────────────────────
    fastify.get('/admin/campaigns', async (request, reply) => {
        const query = request.query as {
            page?: string;
            limit?: string;
            search?: string;
            isActive?: string;
        };

        const page  = Math.max(1, Number(query.page || '1'));
        const limit = Math.min(100, Math.max(1, Number(query.limit || '20')));
        const skip  = (page - 1) * limit;

        const where: any = {};
        if (query.isActive !== undefined && query.isActive !== '') {
            where.isActive = query.isActive === 'true';
        }
        if (query.search) {
            where.OR = [
                { title:  { contains: query.search, mode: 'insensitive' } },
                { slogan: { contains: query.search, mode: 'insensitive' } },
            ];
        }

        const [campaigns, total] = await Promise.all([
            prisma.campaign.findMany({
                where,
                skip,
                take: limit,
                orderBy: { totalWacStaked: 'desc' },
                include: {
                    leader: { select: { id: true, email: true, slogan: true } },
                    _count: { select: { members: true, polls: true } },
                },
            }),
            prisma.campaign.count({ where }),
        ]);

        return reply.send({
            page,
            limit,
            total,
            totalPages: Math.ceil(total / limit),
            campaigns,
        });
    });

    // ── GET /admin/campaigns/:id ────────────────────────────────────────────
    fastify.get('/admin/campaigns/:id', async (request, reply) => {
        const { id } = request.params as { id: string };

        const campaign = await prisma.campaign.findUnique({
            where: { id },
            include: {
                leader: { select: { id: true, email: true, slogan: true } },
                members: {
                    include: {
                        user: { select: { id: true, email: true, slogan: true, isBot: true } },
                    },
                    orderBy: { joinedAt: 'asc' },
                },
                racPool: { select: { totalBalance: true, participantCount: true, isActive: true } },
                _count: { select: { members: true, polls: true } },
            },
        });

        if (!campaign) return reply.code(404).send({ error: 'Campaign not found.' });
        return reply.send({ campaign });
    });

    // ── GET /admin/wallets ──────────────────────────────────────────────────
    fastify.get('/admin/wallets', async (request, reply) => {
        const query = request.query as {
            page?: string;
            limit?: string;
            search?: string;
            sortBy?: string;
            sortDir?: string;
            wacActive?: string;
        };

        const page  = Math.max(1, Number(query.page || '1'));
        const limit = Math.min(100, Math.max(1, Number(query.limit || '20')));
        const skip  = (page - 1) * limit;
        const sortBy = query.sortBy === 'racBalance' ? 'racBalance' : 'wacBalance';
        const sortDir = query.sortDir === 'asc' ? 'asc' as const : 'desc' as const;

        const where: any = {};
        if (query.search) {
            where.OR = [
                { email:  { contains: query.search, mode: 'insensitive' } },
                { slogan: { contains: query.search, mode: 'insensitive' } },
            ];
        }
        if (query.wacActive === 'true') {
            where.wac = { isActive: true };
        }

        const users = await prisma.user.findMany({
            where,
            skip,
            take: limit,
            orderBy: sortBy === 'wacBalance'
                ? { wac: { wacBalance: sortDir } }
                : { rac: { racBalance: sortDir } },
            select: {
                id: true,
                email: true,
                slogan: true,
                isBot: true,
                wac: { select: { wacBalance: true, isActive: true } },
                rac: { select: { racBalance: true } },
            },
        });

        const total = await prisma.user.count({ where });

        return reply.send({
            page,
            limit,
            total,
            totalPages: Math.ceil(total / limit),
            wallets: users.map((u: any) => ({
                id: u.id,
                email: u.email,
                slogan: u.slogan,
                isBot: u.isBot,
                wacBalance: u.wac?.wacBalance?.toString() ?? '0',
                wacActive: u.wac?.isActive ?? false,
                racBalance: u.rac?.racBalance?.toString() ?? '0',
            })),
        });
    });
}
