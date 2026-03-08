import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

// Zod schemas for input validation
const registerSchema = z.object({
    deviceId: z.string().min(5),
    username: z.string().min(3).max(20),
});

const loginSchema = z.object({
    deviceId: z.string().min(5),
});

const socialSchema = z.object({
    provider: z.enum(['google', 'facebook', 'instagram']),
    providerId: z.string().min(3),
    email: z.string().email().optional(),
    username: z.string().min(3).max(20).optional(),
});

export async function authRoutes(fastify: FastifyInstance) {

    // Register a new user device to the map
    fastify.post('/auth/register', async (request, reply) => {
        try {
            const { deviceId, username } = registerSchema.parse(request.body);

            // Check for existing
            const existing = await prisma.user.findUnique({ where: { deviceId } });
            if (existing) {
                return reply.code(409).send({ error: 'Device already registered.' });
            }

            // Create User and their starter Icon in DB
            const user = await prisma.user.create({
                data: {
                    deviceId,
                    tokens: 50, // Initial balance
                    icon: {
                        create: {
                            slogan: 'New Commander',
                            colorHex: '#007AFF',
                            shapeIndex: 0,
                            lastKnownX: 350.0,
                            lastKnownY: 350.0
                        }
                    }
                }
            });

            // Generate JWT Token
            const token = jwt.sign({ userId: user.id, deviceId }, JWT_SECRET, { expiresIn: '30d' });

            return reply.code(201).send({ token, userId: user.id });
        } catch (err: any) {
            fastify.log.error(`Registration failed: ${err}`);
            return reply.code(400).send({ error: 'Invalid payload or internal error' });
        }
    });

    // Login existing user to get fresh JWT token
    fastify.post('/auth/login', async (request, reply) => {
        try {
            const { deviceId } = loginSchema.parse(request.body);

            const user = await prisma.user.findUnique({ where: { deviceId } });
            if (!user) {
                return reply.code(404).send({ error: 'User not found. Need to register.' });
            }

            const token = jwt.sign({ userId: user.id, deviceId }, JWT_SECRET, { expiresIn: '30d' });
            return reply.send({ token, userId: user.id });

        } catch (err: any) {
            return reply.code(400).send({ error: 'Invalid payload' });
        }
    });

    // Social Login / Registration
    fastify.post('/auth/social', async (request, reply) => {
        try {
            const { provider, providerId, email, username } = socialSchema.parse(request.body);

            // Dynamically check which provider was passed
            const providerField = provider === 'google' ? 'googleId'
                : provider === 'facebook' ? 'facebookId'
                    : 'instagramId';

            // Check if user already linked this social account
            let user = await prisma.user.findUnique({
                where: { [providerField]: providerId } as any
            });

            // If new user, create their account and initial Icon
            if (!user) {
                user = await prisma.user.create({
                    data: {
                        [providerField]: providerId,
                        email: email || null,
                        tokens: 100, // Social login bonus!
                        icon: {
                            create: {
                                slogan: username || 'Social Commander',
                                colorHex: '#FF9500', // Social accounts get orange icons
                                shapeIndex: 1,
                                lastKnownX: 350.0,
                                lastKnownY: 350.0
                            }
                        }
                    }
                });
            }

            // Issue the game JWT
            const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
            return reply.send({ token, userId: user.id, isNew: !user });

        } catch (err: any) {
            fastify.log.error(`Social auth failed: ${err}`);
            return reply.code(400).send({ error: 'Invalid social payload' });
        }
    });
}
