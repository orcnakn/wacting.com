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
import { calculateLevel } from './engine/level_calculator.js';
import { webhookRoutes } from './routes/webhook.js';
import { authRoutes } from './routes/auth.js';
import { adminRoutes } from './routes/admin.js';
import { iconRoutes } from './routes/icons.js';
import { socialRoutes } from './routes/social.js';
import { wacRoutes, wacPublicRoutes } from './routes/wac.js';
// import { racRoutes, racPublicRoutes } from './routes/rac.js'; // RAC temporarily disabled
import { feedRoutes } from './routes/feed.js';
import { voteRoutes } from './routes/vote.js';
import { profileRoutes } from './routes/profile.js';
import { campaignRoutes } from './routes/campaign.js';
import { oauthRoutes } from './routes/oauth.js';
import { devNotesRoutes } from './routes/devnotes.js';
import notificationRoutes from './routes/notifications.js';
import { storyRoutes } from './routes/story.js';
// import { registerSnapshotCron } from './workers/snapshot_worker.js';
// import './services/notification_worker.js';

const fastify = Fastify({
    logger: true
});

const prisma = new PrismaClient();
const engine = new MovementEngine();

// Make engine accessible to route handlers
fastify.decorate('engine', engine);

// Stance-based icon color: SUPPORT=green, PROTEST=red, REFORM=unique per campaign
const REFORM_PALETTE = [
    '#E91E63', '#9C27B0', '#673AB7', '#3F51B5', '#2196F3',
    '#00BCD4', '#009688', '#FF9800', '#FF5722', '#795548',
    '#607D8B', '#8BC34A', '#CDDC39', '#FFC107', '#03A9F4',
    '#7C4DFF', '#FF6E40', '#00E676', '#FFD740', '#448AFF',
];
function stanceColor(campaign: any, fallback: string): string {
    if (!campaign) return fallback;
    if (campaign.stanceType === 'SUPPORT') return '#4CAF50';
    if (campaign.stanceType === 'PROTEST') return '#FF9800';
    if (campaign.stanceType === 'REFORM') return '#2196F3';
    return campaign.iconColor ?? fallback;
}

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
                                include: {
                                    campaign: {
                                        include: { _count: { select: { members: true } } }
                                    }
                                },
                                take: 1,
                            }
                        }
                    }
                }
            });

            // Known cities on major landmasses (guaranteed selectable polygon coverage)
            const SPAWN_CITIES = [
                { lat: 40.71, lng: -74.01 },  // New York
                { lat: 34.05, lng: -118.24 }, // Los Angeles
                { lat: 41.88, lng: -87.63 },  // Chicago
                { lat: 51.51, lng: -0.13 },   // London
                { lat: 48.86, lng: 2.35 },    // Paris
                { lat: 52.52, lng: 13.41 },   // Berlin
                { lat: 41.01, lng: 28.98 },   // Istanbul
                { lat: 41.90, lng: 12.50 },   // Rome
                { lat: 40.42, lng: -3.70 },   // Madrid
                { lat: 59.33, lng: 18.07 },   // Stockholm
                { lat: 55.68, lng: 12.57 },   // Copenhagen
                { lat: 50.85, lng: 4.35 },    // Brussels
                { lat: 47.50, lng: 19.04 },   // Budapest
                { lat: 50.08, lng: 14.44 },   // Prague
                { lat: 52.37, lng: 4.90 },    // Amsterdam
                { lat: 35.69, lng: 139.69 },  // Tokyo
                { lat: 37.57, lng: 126.98 },  // Seoul
                { lat: 19.08, lng: 72.88 },   // Mumbai
                { lat: 39.90, lng: 116.41 },  // Beijing
                { lat: 1.35, lng: 103.82 },   // Singapore
                { lat: 25.20, lng: 55.27 },   // Dubai
                { lat: 13.76, lng: 100.50 },  // Bangkok
                { lat: -23.55, lng: -46.63 }, // São Paulo
                { lat: -34.60, lng: -58.38 }, // Buenos Aires
                { lat: 4.71, lng: -74.07 },   // Bogotá
                { lat: 6.52, lng: 3.38 },     // Lagos
                { lat: -33.92, lng: 18.42 },  // Cape Town
                { lat: -1.29, lng: 36.82 },   // Nairobi
                { lat: -33.87, lng: 151.21 }, // Sydney
                { lat: 30.04, lng: 31.24 },   // Cairo
                { lat: 55.75, lng: 37.62 },   // Moscow
                { lat: 33.86, lng: 35.50 },   // Beirut
                { lat: -12.05, lng: -77.04 }, // Lima
                { lat: 19.43, lng: -99.13 },  // Mexico City
                { lat: 45.46, lng: 9.19 },    // Milan
                { lat: 38.72, lng: -9.14 },   // Lisbon
                { lat: 37.98, lng: 23.73 },   // Athens
                { lat: 48.21, lng: 16.37 },   // Vienna
                { lat: 60.17, lng: 24.94 },   // Helsinki
                { lat: 35.68, lng: 51.39 },   // Tehran
            ];

            // Helper: find a random position on land near known cities
            function randomLandPosition(): { x: number, y: number } {
                const city = SPAWN_CITIES[Math.floor(Math.random() * SPAWN_CITIES.length)]!;
                // Scatter within ~3 degrees of a known city
                for (let attempt = 0; attempt < 50; attempt++) {
                    const lat = city.lat + (Math.random() - 0.5) * 6;
                    const lng = city.lng + (Math.random() - 0.5) * 6;
                    if (wc([lng, lat]) != null) {
                        return { x: lngToGridX(lng), y: latToGridY(lat) };
                    }
                }
                // Fallback: exact city position
                return { x: lngToGridX(city.lng), y: latToGridY(city.lat) };
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

                // Level system: compute from member count, age, and WAC staked
                let level = 0, widthMeters = 0, heightMeters = 0;
                if (campaign) {
                    const memberCount = (campaign as any)._count?.members ?? 0;
                    const totalWac = parseFloat(campaign.totalWacStaked?.toString() ?? '0');
                    const lc = calculateLevel(memberCount, campaign.createdAt, totalWac);
                    level = lc.totalLevel;
                    widthMeters = lc.widthMeters;
                    heightMeters = lc.heightMeters;
                }

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

                // Only leaders get campaign tabela data (slogan, level, dimensions).
                // Members keep campaign color but render as user dots, not tabelalar.
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
                    campaignColor: stanceColor(campaign, icon.colorHex),
                    campaignSlogan: isLeader && campaign ? campaign.slogan : undefined,
                    pinnedX,
                    pinnedY,
                    isCampaignLeader: isLeader ?? false,
                    isEmergency: isLeader && campaign?.stanceType === 'EMERGENCY',
                    emergencyAreaM2: isLeader && campaign?.stanceType === 'EMERGENCY' ? ((campaign as any).emergencyAreaM2 ?? 0) : 0,
                    stanceType: campaign?.stanceType ?? undefined,
                    campaignId: campaign?.id ?? undefined,
                    level: isLeader ? level : 0,
                    widthMeters: isLeader ? widthMeters : 0,
                    heightMeters: isLeader ? heightMeters : 0,
                    profileLevel: icon.user?.cachedProfileLevel ?? 1,
                    isPrivate: icon.user?.isPrivate ?? false,
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
            fastify.log.warn('⚠ PostgreSQL unavailable — server will start without DB. WAC routes will return errors.');
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
                    !request.url.startsWith('/wac') &&
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
        // fastify.register(racRoutes);         // RAC temporarily disabled
        // fastify.register(racPublicRoutes);   // RAC temporarily disabled
        fastify.register(feedRoutes, { prefix: '/feed' }); // New Feed APIs
        fastify.register(voteRoutes, { prefix: '/vote' }); // Voting System
        fastify.register(profileRoutes, { prefix: '/api/profile' });
        fastify.register(devNotesRoutes, { prefix: '/api/devnotes' });
        fastify.register(campaignRoutes, { prefix: '/campaign' });
        fastify.register(notificationRoutes, { prefix: '/api/notifications' });
        fastify.register(storyRoutes, { prefix: '/api/story' });

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
