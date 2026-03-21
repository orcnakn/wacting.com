import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import jwt from 'jsonwebtoken';

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

    // ── Get users with location enabled (for map pins) ─────────────────────
    fastify.get('/icons/locations', async (request, reply) => {
        try {
            const icons = await prisma.icon.findMany({
                where: { locationEnabled: true, locationLat: { not: null }, locationLng: { not: null } },
                select: {
                    userId: true,
                    locationLat: true,
                    locationLng: true,
                    locationOffsetMeters: true,
                    colorHex: true,
                    slogan: true,
                    user: { select: { displayName: true, slogan: true, avatarUrl: true } },
                },
            });

            // Apply privacy offset — random direction, fixed distance
            const result = icons.map(icon => {
                const offsetM = icon.locationOffsetMeters || 0;
                let lat = icon.locationLat!;
                let lng = icon.locationLng!;
                if (offsetM > 0) {
                    // Deterministic offset based on userId hash (consistent per user)
                    const hash = icon.userId.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
                    const angle = (hash % 360) * (Math.PI / 180);
                    const mPerDegLat = 111_320;
                    const mPerDegLng = 111_320 * Math.cos(lat * Math.PI / 180);
                    lat += (offsetM * Math.sin(angle)) / mPerDegLat;
                    lng += (offsetM * Math.cos(angle)) / (mPerDegLng || 1);
                }
                return {
                    userId: icon.userId,
                    lat,
                    lng,
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
