import { FastifyInstance } from 'fastify';
import { PrismaClient, Prisma } from '@prisma/client';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
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

const emailRegisterSchema = z.object({
    email: z.string().email(),
    password: z.string().min(6),
    username: z.string().min(3).max(20).optional(),
});

const emailLoginSchema = z.object({
    email: z.string().email(),
    password: z.string().min(1),
});

export async function authRoutes(fastify: FastifyInstance) {

    // ── Email/Password Register ──────────────────────────────────────────────
    fastify.post('/auth/email/register', async (request, reply) => {
        try {
            const { email, password, username } = emailRegisterSchema.parse(request.body);

            const existing = await prisma.user.findUnique({ where: { email } });
            if (existing) {
                return reply.code(409).send({ error: 'Email already registered.' });
            }

            const passwordHash = await bcrypt.hash(password, 10);
            const displayName = (username || email.split('@')[0]) as string;

            const user = await prisma.user.create({
                data: {
                    email,
                    passwordHash,
                    slogan: displayName,
                    icon: {
                        create: {
                            slogan: displayName,
                            colorHex: '#2C3E50',
                            shapeIndex: 0,
                            lastKnownX: 350.0,
                            lastKnownY: 350.0
                        }
                    },
                    wac: {
                        create: {
                            wacBalance: new Prisma.Decimal('1.000000'),
                            isActive: true,
                        }
                    }
                }
            });

            // Log the initial WAC grant
            await prisma.transaction.create({
                data: {
                    userId: user.id,
                    amount: new Prisma.Decimal('1.000000'),
                    type: 'WAC_DEPOSIT',
                    note: 'Welcome bonus: 1 WAC on registration',
                },
            });

            const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
            return reply.code(201).send({ token, userId: user.id, wacBalance: '1.000000' });
        } catch (err: any) {
            fastify.log.error(`Email registration failed: ${err}`);
            return reply.code(400).send({ error: err.message || 'Invalid payload' });
        }
    });

    // ── Email/Password Login ─────────────────────────────────────────────────
    fastify.post('/auth/email/login', async (request, reply) => {
        try {
            const { email, password } = emailLoginSchema.parse(request.body);

            const user = await prisma.user.findUnique({ where: { email } });
            if (!user || !user.passwordHash) {
                return reply.code(401).send({ error: 'Invalid email or password.' });
            }

            const valid = await bcrypt.compare(password, user.passwordHash);
            if (!valid) {
                return reply.code(401).send({ error: 'Invalid email or password.' });
            }

            const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
            return reply.send({ token, userId: user.id });
        } catch (err: any) {
            fastify.log.error(`Email login failed: ${err}`);
            return reply.code(400).send({ error: 'Invalid payload' });
        }
    });

    // Register a new user device to the map
    fastify.post('/auth/register', async (request, reply) => {
        try {
            const { deviceId, username } = registerSchema.parse(request.body);

            const existing = await prisma.user.findUnique({ where: { deviceId } });
            if (existing) {
                return reply.code(409).send({ error: 'Device already registered.' });
            }

            const user = await prisma.user.create({
                data: {
                    deviceId,
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

            const providerField = provider === 'google' ? 'googleId'
                : provider === 'facebook' ? 'facebookId'
                    : 'instagramId';

            let user = await prisma.user.findUnique({
                where: { [providerField]: providerId } as any
            });

            if (!user) {
                user = await prisma.user.create({
                    data: {
                        [providerField]: providerId,
                        email: email || null,
                        icon: {
                            create: {
                                slogan: username || 'Social Commander',
                                colorHex: '#FF9500',
                                shapeIndex: 1,
                                lastKnownX: 350.0,
                                lastKnownY: 350.0
                            }
                        }
                    }
                });
            }

            const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
            return reply.send({ token, userId: user.id, isNew: !user });
        } catch (err: any) {
            fastify.log.error(`Social auth failed: ${err}`);
            return reply.code(400).send({ error: 'Invalid social payload' });
        }
    });
}
