import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import staticFiles from '@fastify/static';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
import { PrismaClient } from '@prisma/client';
import { MovementEngine } from './engine/movement_engine.js';
import wc from 'which-country';
import { GRID_WIDTH, GRID_HEIGHT } from './utils/brownian.js';
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
import { oauthRoutes } from './routes/oauth.js';
import { devNotesRoutes } from './routes/devnotes.js';
import notificationRoutes from './routes/notifications.js';
// import { registerSnapshotCron } from './workers/snapshot_worker.js';
// import './services/notification_worker.js';

const fastify = Fastify({
    logger: true
});

const prisma = new PrismaClient();
const engine = new MovementEngine();

// Make engine accessible to route handlers
fastify.decorate('engine', engine);

async function start() {
    try {
        // 1. Initialize Prisma Database Connection (graceful — server starts even without DB)
        try {
            await prisma.$connect();
            fastify.log.info('Prisma Postgres Connected');

            // Load all DB icons into the physics engine
            const dbIcons = await prisma.icon.findMany({
                include: {
                    user: {
                        include: {
                            wac: true,
                            campaignMemberships: {
                                where: { campaign: { isActive: true } },
                                include: { campaign: true },
                                take: 1,
                            }
                        }
                    }
                }
            });

            // Helper: find a random position on land
            function randomLandPosition(): { x: number, y: number } {
                for (let attempt = 0; attempt < 500; attempt++) {
                    const x = Math.random() * GRID_WIDTH;
                    const y = Math.random() * GRID_HEIGHT;
                    const lng = (x / GRID_WIDTH) * 360 - 180;
                    const lat = 90 - (y / GRID_HEIGHT) * 180;
                    if (wc([lng, lat]) != null) return { x, y };
                }
                // Fallback: Istanbul
                return { x: (28.9784 + 180) / 360 * GRID_WIDTH, y: (90 - 41.0082) / 180 * GRID_HEIGHT };
            }

            // Helper: check if grid position is on land
            function isOnLand(x: number, y: number): boolean {
                const lng = (x / GRID_WIDTH) * 360 - 180;
                const lat = 90 - (y / GRID_HEIGHT) * 180;
                return wc([lng, lat]) != null;
            }

            // Helper: convert lng/lat to grid coords
            function lngToGridX(lng: number): number {
                return (lng + 180) / 360 * GRID_WIDTH;
            }
            function latToGridY(lat: number): number {
                return (90 - lat) / 180 * GRID_HEIGHT;
            }

            let relocatedCount = 0;
            for (const icon of dbIcons) {
                const wacBal = parseFloat(icon.user?.wac?.wacBalance?.toString() ?? '0');
                const campaign = icon.user?.campaignMemberships?.[0]?.campaign;
                const size = wacBal > 0
                    ? Math.max(1, Math.log10(wacBal + 1) * 20)
                    : Math.max(1, icon.followerCount * 0.5 + 1);

                let x = icon.lastKnownX;
                let y = icon.lastKnownY;

                // Detect raw lng/lat stored as grid coords (legacy bug):
                // Valid grid coords are 0..715 for x and 0..714 for y.
                // Raw lng values are -180..180, raw lat values are -90..90.
                // If x is negative or y looks like latitude (small positive), convert.
                const looksLikeRawLngLat = x < 0 || x > GRID_WIDTH || y < 0 || y > GRID_HEIGHT ||
                    (Math.abs(x) <= 180 && Math.abs(y) <= 90 && x < GRID_WIDTH / 2);
                if (looksLikeRawLngLat && (x !== 0 || y !== 0)) {
                    // x was stored as longitude, y as latitude
                    x = lngToGridX(x);
                    y = latToGridY(y);
                }

                // Ensure icon starts on land — relocate if on ocean
                if (!isOnLand(x, y)) {
                    const land = randomLandPosition();
                    x = land.x;
                    y = land.y;
                    relocatedCount++;
                }

                // Persist corrected position to DB
                if (x !== icon.lastKnownX || y !== icon.lastKnownY) {
                    prisma.icon.update({
                        where: { id: icon.id },
                        data: { lastKnownX: x, lastKnownY: y }
                    }).catch(err => fastify.log.error(`Failed to update icon position: ${err}`));
                }

                // Campaign leader pinned position → grid coords
                const isLeader = campaign?.leaderId === icon.userId;
                let pinnedX: number | null = null;
                let pinnedY: number | null = null;
                if (isLeader && campaign?.pinnedLat != null && campaign?.pinnedLng != null) {
                    pinnedX = lngToGridX(campaign.pinnedLng);
                    pinnedY = latToGridY(campaign.pinnedLat);
                }

                engine.icons.set(icon.userId, {
                    id: icon.id,
                    userId: icon.userId,
                    x: pinnedX ?? x,
                    y: pinnedY ?? y,
                    vx: 0,
                    vy: 0,
                    baseSpeed: 1.0,
                    size,
                    wacBalance: wacBal,
                    exploreMode: icon.exploreMode,
                    campaignSpeed: campaign?.speed ?? 0.5,
                    campaignColor: campaign?.iconColor ?? icon.colorHex,
                    campaignSlogan: campaign?.slogan ?? icon.slogan ?? undefined,
                    pinnedX,
                    pinnedY,
                    isCampaignLeader: isLeader ?? false,
                    restrictedContinents: (icon as any).restrictedContinents ?? [],
                    restrictedCountries: (icon as any).restrictedCountries ?? [],
                    restrictedCities: (icon as any).restrictedCities ?? [],
                });
            }
            if (relocatedCount > 0) {
                fastify.log.info(`Relocated ${relocatedCount} icons from ocean to land`);
            }
            fastify.log.info(`Loaded ${dbIcons.length} icons from DB into engine`);

        } catch (dbErr) {
            fastify.log.warn('⚠ PostgreSQL unavailable — server will start without DB. WAC/RAC routes will return errors.');
            // Fallback: inject mock icons for testing
            for (let i = 0; i < 10; i++) {
                engine.icons.set(`mock_${i}`, {
                    id: `mock_${i}`,
                    userId: `mockUserId_${i}`,
                    x: 100 + (Math.random() * 310),
                    y: 100 + (Math.random() * 310),
                    vx: 0, vy: 0,
                    baseSpeed: 1 + Math.random(),
                    size: 15 + (Math.random() * 100),
                    wacBalance: 0,
                    exploreMode: 0,
                    campaignSpeed: 0.5,
                });
            }
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

        // 5a. CORS — must be first so preflight OPTIONS gets correct headers
        const allowedOrigins = process.env.NODE_ENV === 'production'
            ? ['https://wacting.com', 'https://www.wacting.com']
            : true; // allow all in development
        await fastify.register(cors, {
            origin: allowedOrigins,
            methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
            allowedHeaders: ['Content-Type', 'Authorization'],
            credentials: true
        });

        // 5b. Security headers
        await fastify.register(helmet, {
            contentSecurityPolicy: false // Flutter web manages its own CSP
        });

        // 5c. Rate limiting — OPTIONS (preflight) requests bypass via allowList logic
        await fastify.register(rateLimit, {
            max: 100,
            timeWindow: '1 minute',
            allowList: ['127.0.0.1'],
            keyGenerator: (req) => {
                // Preflight requests don't count toward rate limit
                if (req.method === 'OPTIONS') return 'preflight_bypass';
                return req.ip;
            }
        });

        // 6. Serve Flutter web build (SPA)
        const webRoot = join(__dirname, 'public', 'web');
        if (existsSync(webRoot)) {
            await fastify.register(staticFiles, {
                root: webRoot,
                prefix: '/',
                decorateReply: false,
            });
            // SPA fallback — all unmatched routes serve index.html
            fastify.setNotFoundHandler(async (request, reply) => {
                if (!request.url.startsWith('/api') && !request.url.startsWith('/auth') &&
                    !request.url.startsWith('/wac') && !request.url.startsWith('/rac') &&
                    !request.url.startsWith('/feed') && !request.url.startsWith('/vote') &&
                    !request.url.startsWith('/campaign') && !request.url.startsWith('/social') &&
                    !request.url.startsWith('/icon') && !request.url.startsWith('/admin') &&
                    !request.url.startsWith('/ping') && !request.url.startsWith('/webhook')) {
                    return reply.sendFile('index.html');
                }
                reply.code(404).send({ error: 'Not found' });
            });
            fastify.log.info(`Flutter web served from ${webRoot}`);
        } else {
            fastify.log.warn(`Flutter web build not found at ${webRoot} — only API will be served`);
        }

        // 7. HTTP routing
        fastify.register(webhookRoutes);
        fastify.register(authRoutes);
        fastify.register(oauthRoutes);
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
        fastify.register(devNotesRoutes, { prefix: '/api/devnotes' });
        fastify.register(campaignRoutes, { prefix: '/campaign' });
        fastify.register(notificationRoutes, { prefix: '/api/notifications' });

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
