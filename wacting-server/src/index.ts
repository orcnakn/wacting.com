import Fastify from 'fastify';
import cors from '@fastify/cors';
import { PrismaClient } from '@prisma/client';
import { MovementEngine } from './engine/movement_engine.js';
import { SocketManager } from './socket/socket_manager.js';
import { webhookRoutes } from './routes/webhook.js';
import { authRoutes } from './routes/auth.js';
import { adminRoutes } from './routes/admin.js';
import { iconRoutes } from './routes/icons.js';
import { socialRoutes } from './routes/social.js';
import { wacRoutes, wacPublicRoutes } from './routes/wac.js';
import { racRoutes, racPublicRoutes } from './routes/rac.js';
import { feedRoutes } from './routes/feed.js';
import { voteRoutes } from './routes/vote.js';
import { profileRoutes } from './routes/profile.js';
import { campaignRoutes } from './routes/campaign.js';
// import { registerSnapshotCron } from './workers/snapshot_worker.js';
// import './services/notification_worker.js';

const fastify = Fastify({
    logger: true
});

const prisma = new PrismaClient();
const engine = new MovementEngine();

async function start() {
    try {
        // Inject Mock Testing Icons
        for (let i = 0; i < 10; i++) {
            engine.icons.set(`mock_${i}`, {
                id: `mock_${i}`,
                userId: `mockUserId_${i}`,
                x: 100 + (Math.random() * 500),
                y: 100 + (Math.random() * 500),
                vx: 0,
                vy: 0,
                baseSpeed: 1 + Math.random(),
                size: 15 + (Math.random() * 100),
                wacBalance: 0,   // WAC balance drives map size
                exploreMode: 0
            });
        }

        // 1. Initialize Prisma Database Connection (graceful — server starts even without DB)
        try {
            await prisma.$connect();
            fastify.log.info('Prisma Postgres Connected');
        } catch (dbErr) {
            fastify.log.warn('⚠ PostgreSQL unavailable — server will start without DB. WAC/RAC routes will return errors.');
        }

        // 2. Start WebSocket Manager passing our physics engine instance
        const socketManager = new SocketManager(fastify.server, engine);
        socketManager.init();

        // 3. Start physics simulation
        engine.start();
        fastify.log.info('Wacting Physics Engine Running (5Hz)');

        // 4. Register WAC midnight snapshot cron (BullMQ)
        // await registerSnapshotCron();
        // fastify.log.info('WAC Snapshot Cron Registered (midnight UTC)');

        // 5. CORS — allow browser requests from any origin (dev + prod)
        await fastify.register(cors, {
            origin: true,
            methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
            allowedHeaders: ['Content-Type', 'Authorization'],
            credentials: true
        });

        // 6. HTTP routing
        fastify.register(webhookRoutes);
        fastify.register(authRoutes);
        fastify.register(adminRoutes);
        fastify.register(iconRoutes);
        fastify.register(socialRoutes);
        fastify.register(wacRoutes);            // authenticated WAC endpoints
        fastify.register(wacPublicRoutes);      // public leaderboard
        fastify.register(racRoutes);            // authenticated RAC endpoints
        fastify.register(racPublicRoutes);      // public protest pool stats
        fastify.register(feedRoutes, { prefix: '/feed' }); // New Feed APIs
        fastify.register(voteRoutes, { prefix: '/vote' }); // Voting System
        fastify.register(profileRoutes, { prefix: '/api/profile' });
        fastify.register(campaignRoutes, { prefix: '/campaign' });

        fastify.get('/ping', async (request, reply) => {
            return { status: 'ok', time: Date.now(), total_icons: engine.icons.size };
        });

        await fastify.listen({ port: 3000, host: '0.0.0.0' });
        fastify.log.info('Wacting Server fully mounted and listening on port 3000');
    } catch (err) {
        fastify.log.error(err);
        process.exit(1);
    }
}

start();
