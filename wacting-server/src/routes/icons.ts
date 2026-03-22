import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import jwt from 'jsonwebtoken';
import wc from 'which-country';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

// Input payload schema for map click updates
const boundsSchema = z.object({
    restrictedContinents: z.array(z.string()).optional(),
    restrictedCountries: z.array(z.string()).optional(),
    restrictedCities: z.array(z.string()).optional()
});

export async function iconRoutes(fastify: FastifyInstance) {

    // Helper hook to verify standard user JWT
    fastify.addHook('preHandler', async (request, reply) => {
        // Skip auth check for public routes if any existed here
        if (request.routeOptions?.url?.startsWith('/public')) return;

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

    // Returns current user's own icon position from the physics engine
    fastify.get('/icons/my-position', async (request, reply) => {
        const userId = (request as any).userId;
        const GRID_WIDTH = 715;
        const GRID_HEIGHT = 714;
        try {
            const engine = (fastify as any).engine;
            if (engine) {
                const iconState = engine.icons.get(userId);
                if (iconState) {
                    const lat = 90 - (iconState.y / GRID_HEIGHT) * 180;
                    const lng = (iconState.x / GRID_WIDTH) * 360 - 180;
                    return reply.send({ success: true, lat, lng });
                }
            }
            // Fallback: DB last known position
            const icon = await prisma.icon.findUnique({
                where: { userId },
                select: { lastKnownX: true, lastKnownY: true },
            });
            if (icon) {
                const lat = 90 - (icon.lastKnownY / GRID_HEIGHT) * 180;
                const lng = (icon.lastKnownX / GRID_WIDTH) * 360 - 180;
                return reply.send({ success: true, lat, lng });
            }
            return reply.code(404).send({ error: 'Icon not found' });
        } catch (err: any) {
            return reply.code(500).send({ error: 'Failed to fetch position' });
        }
    });

    fastify.get('/icons/my-bounds', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const icon = await prisma.icon.findUnique({
                where: { userId },
                select: {
                    restrictedContinents: true,
                    restrictedCountries: true,
                    restrictedCities: true,
                },
            });
            return reply.send({
                success: true,
                restrictedContinents: icon?.restrictedContinents ?? [],
                restrictedCountries:  icon?.restrictedCountries  ?? [],
                restrictedCities:     icon?.restrictedCities     ?? [],
            });
        } catch (err: any) {
            fastify.log.error(`Failed to fetch bounds: ${err}`);
            return reply.code(500).send({ error: 'Failed to fetch bounds' });
        }
    });

    fastify.post('/icons/restrict_bounds', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const data = boundsSchema.parse(request.body);

            // Update Prisma Icon
            const updatedIcon = await prisma.icon.update({
                where: { userId },
                data: {
                    restrictedContinents: data.restrictedContinents || [],
                    restrictedCountries: data.restrictedCountries || [],
                    restrictedCities: data.restrictedCities || []
                }
            });

            fastify.log.info(`Updated geo-bounds for User ${userId}`);

            // Update in-memory engine icon immediately
            const engine = (fastify as any).engine;
            if (engine) {
                const iconState = engine.icons.get(userId);
                if (iconState) {
                    iconState.restrictedContinents = data.restrictedContinents || [];
                    iconState.restrictedCountries = data.restrictedCountries || [];
                    iconState.restrictedCities = data.restrictedCities || [];
                    iconState._allowedIso3 = undefined; // Force recalculation
                }
            }

            return reply.send({ success: true, icon: updatedIcon });

        } catch (err: any) {
            fastify.log.error(`Failed to restrict bounds: ${err}`);
            return reply.code(400).send({ error: 'Invalid bounds payload' });
        }
    });

    // Top 100 Global Rankings
    fastify.get('/icons/top', async (request, reply) => {
        try {
            const topIcons = await prisma.icon.findMany({
                orderBy: {
                    followerCount: 'desc'
                },
                take: 100,
                include: {
                    user: {
                        select: {
                            id: true,
                            email: true,
                            role: true,
                            wac: { select: { wacBalance: true } }
                        }
                    }
                }
            });

            // Map the WAC balance Decimal to String for JSON serialization
            const formatted = topIcons.map((icon: any) => ({
                ...icon,
                user: {
                    ...icon.user,
                    wacBalance: icon.user.wac?.wacBalance?.toString() ?? '0'
                }
            }));
            return reply.send({ top: formatted });
        } catch (err: any) {
            fastify.log.error(`Failed to fetch top 100: ${err}`);
            return reply.code(500).send({ error: 'Server error' });
        }
    });

    // Global Search
    fastify.get('/icons/search', async (request, reply) => {
        const query = (request.query as any).q;
        if (!query || typeof query !== 'string') {
            return reply.code(400).send({ error: 'Query parameter "q" is required' });
        }

        try {
            // Search by slogan, email, or campaign title/slogan
            const icons = await prisma.icon.findMany({
                where: {
                    OR: [
                        { slogan: { contains: query, mode: 'insensitive' } },
                        { user: { email: { contains: query, mode: 'insensitive' } } },
                        { user: { campaignMemberships: { some: { campaign: {
                            OR: [
                                { title: { contains: query, mode: 'insensitive' } },
                                { slogan: { contains: query, mode: 'insensitive' } }
                            ]
                        } } } } }
                    ]
                },
                take: 20,
                include: {
                    user: {
                        select: {
                            id: true,
                            email: true,
                            wac: { select: { wacBalance: true } },
                            campaignMemberships: {
                                select: {
                                    campaign: {
                                        select: { id: true, title: true, slogan: true, iconColor: true, isActive: true }
                                    }
                                },
                                take: 3
                            }
                        }
                    }
                }
            });

            const formatted = icons.map((icon: any) => ({
                ...icon,
                user: {
                    ...icon.user,
                    wacBalance: icon.user.wac?.wacBalance?.toString() ?? '0',
                    campaigns: icon.user.campaignMemberships?.map((cm: any) => cm.campaign) ?? []
                }
            }));
            return reply.send({ results: formatted });
        } catch (err: any) {
            fastify.log.error(`Search failed: ${err}`);
            return reply.code(500).send({ error: 'Server error' });
        }
    });

    // ── Update user location (GPS) ──────────────────────────────────────────
    const locationSchema = z.object({
        locationEnabled: z.boolean(),
        locationLat: z.number().min(-90).max(90).optional(),
        locationLng: z.number().min(-180).max(180).optional(),
        locationOffsetMeters: z.number().min(0).max(50000).optional(),
    });

    fastify.post('/icons/location', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const data = locationSchema.parse(request.body);

            const updateData: any = {
                locationEnabled: data.locationEnabled,
            };

            if (data.locationLat != null) updateData.locationLat = data.locationLat;
            if (data.locationLng != null) updateData.locationLng = data.locationLng;
            if (data.locationOffsetMeters != null) updateData.locationOffsetMeters = data.locationOffsetMeters;

            // If disabling, clear location
            if (!data.locationEnabled) {
                updateData.locationLat = null;
                updateData.locationLng = null;
            }

            await prisma.icon.update({
                where: { userId },
                data: updateData,
            });

            return reply.send({ success: true });
        } catch (err: any) {
            fastify.log.error(`Location update failed: ${err}`);
            return reply.code(500).send({ error: 'Server error' });
        }
    });

    // ── Get ALL users for map pins ─────────────────────────────────────────
    // - Location enabled + has coords → real location (with privacy offset)
    // - Location disabled + has restricted regions → random position in selected regions
    // - No regions selected → random position anywhere on land
    fastify.get('/icons/locations', async (request, reply) => {
        try {
            const icons = await prisma.icon.findMany({
                select: {
                    userId: true,
                    locationEnabled: true,
                    locationLat: true,
                    locationLng: true,
                    locationOffsetMeters: true,
                    colorHex: true,
                    slogan: true,
                    restrictedContinents: true,
                    restrictedCountries: true,
                    restrictedCities: true,
                    user: { select: { displayName: true, slogan: true, avatarUrl: true } },
                },
            });

            const result = icons.map(icon => {
                let lat: number;
                let lng: number;
                let isRealLocation = false;

                if (icon.locationEnabled && icon.locationLat != null && icon.locationLng != null) {
                    // Real GPS location with privacy offset
                    lat = icon.locationLat;
                    lng = icon.locationLng;
                    isRealLocation = true;
                    const offsetM = icon.locationOffsetMeters || 0;
                    if (offsetM > 0) {
                        const hash = icon.userId.split('').reduce((a: number, c: string) => a + c.charCodeAt(0), 0);
                        const angle = (hash % 360) * (Math.PI / 180);
                        const mPerDegLat = 111_320;
                        const mPerDegLng = 111_320 * Math.cos(lat * Math.PI / 180);
                        lat += (offsetM * Math.sin(angle)) / mPerDegLat;
                        lng += (offsetM * Math.cos(angle)) / (mPerDegLng || 1);
                    }
                } else {
                    // Generate deterministic random position based on userId
                    const pos = generateRandomPosition(
                        icon.userId,
                        icon.restrictedContinents || [],
                        icon.restrictedCountries || [],
                        icon.restrictedCities || [],
                    );
                    lat = pos.lat;
                    lng = pos.lng;
                }

                return {
                    userId: icon.userId,
                    lat,
                    lng,
                    isRealLocation,
                    colorHex: icon.colorHex,
                    slogan: icon.slogan,
                    displayName: icon.user?.displayName || icon.user?.slogan || '',
                    avatarUrl: icon.user?.avatarUrl,
                };
            });

            return reply.send({ locations: result });
        } catch (err: any) {
            fastify.log.error(`Locations fetch failed: ${err}`);
            return reply.code(500).send({ error: 'Server error' });
        }
    });
}

// ── Continent bounding boxes (lat/lng) ──────────────────────────────────────
const CONTINENT_BOUNDS: Record<string, { minLat: number; maxLat: number; minLng: number; maxLng: number }> = {
    'Europe':        { minLat: 35, maxLat: 71, minLng: -25, maxLng: 45 },
    'Asia':          { minLat: -10, maxLat: 55, minLng: 25, maxLng: 150 },
    'Africa':        { minLat: -35, maxLat: 37, minLng: -18, maxLng: 52 },
    'North America': { minLat: 7, maxLat: 72, minLng: -170, maxLng: -50 },
    'South America': { minLat: -56, maxLat: 13, minLng: -82, maxLng: -34 },
    'Oceania':       { minLat: -47, maxLat: -10, minLng: 110, maxLng: 180 },
    'Antarctica':    { minLat: -85, maxLat: -60, minLng: -180, maxLng: 180 },
};

// Major country bounding boxes for random placement
const COUNTRY_BOUNDS: Record<string, { minLat: number; maxLat: number; minLng: number; maxLng: number }> = {
    'Turkey':        { minLat: 36, maxLat: 42, minLng: 26, maxLng: 45 },
    'Germany':       { minLat: 47, maxLat: 55, minLng: 6, maxLng: 15 },
    'France':        { minLat: 42, maxLat: 51, minLng: -5, maxLng: 8 },
    'United Kingdom':{ minLat: 50, maxLat: 59, minLng: -8, maxLng: 2 },
    'Italy':         { minLat: 36, maxLat: 47, minLng: 6, maxLng: 19 },
    'Spain':         { minLat: 36, maxLat: 44, minLng: -9, maxLng: 4 },
    'United States of America': { minLat: 25, maxLat: 49, minLng: -125, maxLng: -67 },
    'United States': { minLat: 25, maxLat: 49, minLng: -125, maxLng: -67 },
    'Canada':        { minLat: 42, maxLat: 70, minLng: -141, maxLng: -52 },
    'Brazil':        { minLat: -33, maxLat: 5, minLng: -74, maxLng: -35 },
    'Russia':        { minLat: 41, maxLat: 77, minLng: 27, maxLng: 180 },
    'China':         { minLat: 18, maxLat: 54, minLng: 73, maxLng: 135 },
    'India':         { minLat: 6, maxLat: 36, minLng: 68, maxLng: 97 },
    'Japan':         { minLat: 24, maxLat: 46, minLng: 123, maxLng: 146 },
    'Australia':     { minLat: -44, maxLat: -10, minLng: 113, maxLng: 154 },
    'Mexico':        { minLat: 14, maxLat: 33, minLng: -118, maxLng: -87 },
    'Argentina':     { minLat: -55, maxLat: -22, minLng: -73, maxLng: -53 },
    'Egypt':         { minLat: 22, maxLat: 32, minLng: 25, maxLng: 37 },
    'South Africa':  { minLat: -35, maxLat: -22, minLng: 16, maxLng: 33 },
    'Nigeria':       { minLat: 4, maxLat: 14, minLng: 3, maxLng: 15 },
    'Indonesia':     { minLat: -11, maxLat: 6, minLng: 95, maxLng: 141 },
    'South Korea':   { minLat: 33, maxLat: 39, minLng: 124, maxLng: 132 },
    'Saudi Arabia':  { minLat: 16, maxLat: 32, minLng: 34, maxLng: 56 },
    'Iran':          { minLat: 25, maxLat: 40, minLng: 44, maxLng: 64 },
    'Pakistan':      { minLat: 24, maxLat: 37, minLng: 61, maxLng: 77 },
    'Bangladesh':    { minLat: 20, maxLat: 27, minLng: 88, maxLng: 93 },
    'Thailand':      { minLat: 5, maxLat: 21, minLng: 97, maxLng: 106 },
    'Vietnam':       { minLat: 8, maxLat: 24, minLng: 102, maxLng: 110 },
    'Philippines':   { minLat: 5, maxLat: 21, minLng: 117, maxLng: 127 },
    'Poland':        { minLat: 49, maxLat: 55, minLng: 14, maxLng: 24 },
    'Ukraine':       { minLat: 44, maxLat: 52, minLng: 22, maxLng: 40 },
    'Netherlands':   { minLat: 51, maxLat: 54, minLng: 3, maxLng: 7 },
    'Belgium':       { minLat: 49, maxLat: 52, minLng: 2, maxLng: 7 },
    'Sweden':        { minLat: 55, maxLat: 69, minLng: 11, maxLng: 24 },
    'Norway':        { minLat: 58, maxLat: 71, minLng: 5, maxLng: 31 },
    'Greece':        { minLat: 35, maxLat: 42, minLng: 19, maxLng: 30 },
    'Portugal':      { minLat: 37, maxLat: 42, minLng: -10, maxLng: -6 },
    'Switzerland':   { minLat: 46, maxLat: 48, minLng: 6, maxLng: 10 },
    'Austria':       { minLat: 46, maxLat: 49, minLng: 10, maxLng: 17 },
    'Colombia':      { minLat: -4, maxLat: 14, minLng: -79, maxLng: -67 },
    'Peru':          { minLat: -18, maxLat: 0, minLng: -81, maxLng: -69 },
    'Chile':         { minLat: -56, maxLat: -17, minLng: -76, maxLng: -67 },
    'New Zealand':   { minLat: -47, maxLat: -34, minLng: 166, maxLng: 179 },
};

// Default world land bounds (excluding deep ocean/poles)
const WORLD_LAND_BOUNDS = { minLat: -50, maxLat: 65, minLng: -170, maxLng: 175 };

/**
 * Deterministic pseudo-random number generator (mulberry32) seeded by userId.
 * Returns a function that produces values in [0, 1).
 */
function seededRng(userId: string): () => number {
    let seed = 0;
    for (let i = 0; i < userId.length; i++) {
        seed = ((seed << 5) - seed + userId.charCodeAt(i)) | 0;
    }
    return () => {
        seed |= 0;
        seed = (seed + 0x6D2B79F5) | 0;
        let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// Known cities for spawning within selectable polygon areas
const SPAWN_CITIES = [
    { lat: 40.71, lng: -74.01 },  { lat: 34.05, lng: -118.24 },
    { lat: 41.88, lng: -87.63 },  { lat: 51.51, lng: -0.13 },
    { lat: 48.86, lng: 2.35 },    { lat: 52.52, lng: 13.41 },
    { lat: 41.01, lng: 28.98 },   { lat: 41.90, lng: 12.50 },
    { lat: 40.42, lng: -3.70 },   { lat: 59.33, lng: 18.07 },
    { lat: 35.69, lng: 139.69 },  { lat: 37.57, lng: 126.98 },
    { lat: 19.08, lng: 72.88 },   { lat: 39.90, lng: 116.41 },
    { lat: 25.20, lng: 55.27 },   { lat: 13.76, lng: 100.50 },
    { lat: -23.55, lng: -46.63 }, { lat: -34.60, lng: -58.38 },
    { lat: 6.52, lng: 3.38 },     { lat: -33.92, lng: 18.42 },
    { lat: -1.29, lng: 36.82 },   { lat: -33.87, lng: 151.21 },
    { lat: 30.04, lng: 31.24 },   { lat: 55.75, lng: 37.62 },
    { lat: 19.43, lng: -99.13 },  { lat: -12.05, lng: -77.04 },
    { lat: 37.98, lng: 23.73 },   { lat: 48.21, lng: 16.37 },
    { lat: 60.17, lng: 24.94 },   { lat: 35.68, lng: 51.39 },
];

/**
 * Generate a deterministic random lat/lng based on userId and their selected regions.
 * Ensures position is always within selectable country polygons.
 */
function generateRandomPosition(
    userId: string,
    restrictedContinents: string[],
    restrictedCountries: string[],
    restrictedCities: string[],
): { lat: number; lng: number } {
    const rng = seededRng(userId);

    // If user has restricted countries, use their bounding boxes
    if (restrictedCountries.length > 0) {
        const idx = Math.floor(rng() * restrictedCountries.length);
        const country = restrictedCountries[idx]!;
        const bounds = COUNTRY_BOUNDS[country];
        if (bounds) {
            for (let attempt = 0; attempt < 50; attempt++) {
                const lat = bounds.minLat + rng() * (bounds.maxLat - bounds.minLat);
                const lng = bounds.minLng + rng() * (bounds.maxLng - bounds.minLng);
                if (wc([lng, lat]) != null) return { lat, lng };
            }
        }
    }

    // If user has restricted continents, use their bounding boxes
    if (restrictedContinents.length > 0) {
        const idx = Math.floor(rng() * restrictedContinents.length);
        const continent = restrictedContinents[idx]!;
        const bounds = CONTINENT_BOUNDS[continent];
        if (bounds) {
            for (let attempt = 0; attempt < 50; attempt++) {
                const lat = bounds.minLat + rng() * (bounds.maxLat - bounds.minLat);
                const lng = bounds.minLng + rng() * (bounds.maxLng - bounds.minLng);
                if (wc([lng, lat]) != null) return { lat, lng };
            }
        }
    }

    // No restrictions: pick a known city and scatter nearby
    const cityIdx = Math.floor(rng() * SPAWN_CITIES.length);
    const city = SPAWN_CITIES[cityIdx]!;
    for (let attempt = 0; attempt < 50; attempt++) {
        const lat = city.lat + (rng() - 0.5) * 6;
        const lng = city.lng + (rng() - 0.5) * 6;
        if (wc([lng, lat]) != null) return { lat, lng };
    }

    // Fallback: exact city
    return { lat: city.lat, lng: city.lng };
}
