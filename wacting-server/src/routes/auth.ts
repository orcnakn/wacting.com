import { FastifyInstance } from 'fastify';
import { PrismaClient, Prisma } from '@prisma/client';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { sendVerificationCode, sendWelcomeEmail } from '../services/email_service.js';
import { recordChainedTransaction } from '../engine/chain_engine.js';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

// ─── Helper: generate 6-digit code ──────────────────────────────────────────
function generate6DigitCode(): string {
    return String(Math.floor(100000 + Math.random() * 900000));
}

// ─── Helper: tiered welcome bonus ────────────────────────────────────────────
// İlk 1000 kişi → 100 WAC, sonraki 9000 (1001–10000) → 10 WAC, sonrası → 1 WAC
async function getWelcomeBonus(): Promise<{ amount: string; note: string }> {
    const count = await prisma.user.count();
    if (count < 1000) {
        return { amount: '100.000000', note: `Welcome bonus: 100 WAC (Early Adopter #${count + 1})` };
    } else if (count < 10000) {
        return { amount: '10.000000', note: `Welcome bonus: 10 WAC (Early Supporter #${count + 1})` };
    } else {
        return { amount: '1.000000', note: 'Welcome bonus: 1 WAC on registration' };
    }
}

// ─── Zod schemas ─────────────────────────────────────────────────────────────
const registerSchema = z.object({
    deviceId: z.string().min(5),
    username: z.string().min(3).max(20),
});

const loginSchema = z.object({
    deviceId: z.string().min(5),
});

const socialSchema = z.object({
    provider: z.enum(['google', 'facebook', 'instagram', 'twitter', 'tiktok', 'linkedin', 'apple', 'steam']),
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

const verifyCodeSchema = z.object({
    email: z.string().email(),
    code: z.string().length(6),
});

export async function authRoutes(fastify: FastifyInstance) {

    // ══════════════════════════════════════════════════════════════════════════
    // EMAIL/PASSWORD REGISTER
    // 1) Kullanıcı oluştur (emailVerified = false)
    // 2) 6 haneli kod üret ve emaile gönder
    // 3) Token DÖNME — kullanıcı önce kodu doğrulamalı
    // ══════════════════════════════════════════════════════════════════════════
    fastify.post('/auth/email/register', async (request, reply) => {
        try {
            const { email, password, username } = emailRegisterSchema.parse(request.body);

            // Zaten kayıtlı mı?
            const existing = await prisma.user.findUnique({ where: { email } });
            if (existing && existing.emailVerified) {
                return reply.code(409).send({ error: 'Bu email adresi zaten kayıtlı.' });
            }

            const code = generate6DigitCode();
            const passwordHash = await bcrypt.hash(password, 10);
            const displayName = (username || email.split('@')[0]) as string;

            if (existing && !existing.emailVerified) {
                // Kayıt var ama doğrulanmamış — kodu yenile, şifreyi güncelle
                await prisma.user.update({
                    where: { id: existing.id },
                    data: { passwordHash, emailVerifyToken: code, slogan: displayName },
                });
            } else {
                // Yeni kullanıcı
                const bonus = await getWelcomeBonus();
                const user = await prisma.user.create({
                    data: {
                        email,
                        passwordHash,
                        slogan: displayName,
                        emailVerified: false,
                        emailVerifyToken: code,
                        icon: {
                            create: {
                                slogan: displayName,
                                colorHex: '#2C3E50',
                                shapeIndex: 0,
                                lastKnownX: 350.0,
                                lastKnownY: 350.0,
                            },
                        },
                        wac: {
                            create: {
                                wacBalance: new Prisma.Decimal(bonus.amount),
                                isActive: true,
                            },
                        },
                    },
                });

                await prisma.$transaction(async (tx) => {
                    await recordChainedTransaction(tx, {
                        userId: user.id,
                        amount: bonus.amount,
                        type: 'WAC_WELCOME_BONUS' as any,
                        note: bonus.note,
                    });
                });
            }

            // Kodu emaile gönder
            sendVerificationCode(email, code).catch((err: any) => {
                fastify.log.error(`[Auth] Failed to send verification code to ${email}: ${err}`);
            });

            return reply.code(201).send({
                success: true,
                needsVerification: true,
                message: 'Aktivasyon kodu email adresinize gönderildi.',
            });
        } catch (err: any) {
            fastify.log.error(`Email registration failed: ${err}`);
            return reply.code(400).send({ error: err.message || 'Geçersiz veri' });
        }
    });

    // ══════════════════════════════════════════════════════════════════════════
    // VERIFY 6-DIGIT CODE
    // Kod doğruysa → emailVerified = true, JWT token döndür
    // ══════════════════════════════════════════════════════════════════════════
    fastify.post('/auth/verify-code', async (request, reply) => {
        try {
            const { email, code } = verifyCodeSchema.parse(request.body);

            const user = await prisma.user.findUnique({ where: { email } });
            if (!user) {
                return reply.code(404).send({ error: 'Kullanıcı bulunamadı.' });
            }
            if (user.emailVerified) {
                return reply.code(409).send({ error: 'Email zaten doğrulanmış. Giriş yapabilirsiniz.' });
            }
            if (user.emailVerifyToken !== code) {
                return reply.code(400).send({ error: 'Aktivasyon kodu hatalı.' });
            }

            await prisma.user.update({
                where: { id: user.id },
                data: { emailVerified: true, emailVerifyToken: null },
            });

            const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });

            fastify.log.info(`[Auth] Email verified: ${email}`);

            // Aktivasyon tamamlandı maili gönder
            sendWelcomeEmail(email, user.slogan || email.split('@')[0] || 'Commander').catch((err: any) => {
                fastify.log.error(`[Auth] Failed to send welcome email: ${err}`);
            });

            return reply.send({
                success: true,
                token,
                userId: user.id,
                emailVerified: true,
                message: 'Email doğrulandı! Hoş geldiniz.',
            });
        } catch (err: any) {
            fastify.log.error(`Verification failed: ${err}`);
            return reply.code(400).send({ error: err.message || 'Doğrulama başarısız.' });
        }
    });

    // ══════════════════════════════════════════════════════════════════════════
    // RESEND VERIFICATION CODE
    // ══════════════════════════════════════════════════════════════════════════
    fastify.post('/auth/resend-verification', async (request, reply) => {
        try {
            const { email } = request.body as { email?: string };
            if (!email) return reply.code(400).send({ error: 'Email gerekli.' });

            const user = await prisma.user.findUnique({ where: { email } });
            if (!user) return reply.code(404).send({ error: 'Kullanıcı bulunamadı.' });
            if (user.emailVerified) return reply.code(409).send({ error: 'Email zaten doğrulanmış.' });

            const newCode = generate6DigitCode();
            await prisma.user.update({
                where: { id: user.id },
                data: { emailVerifyToken: newCode },
            });

            sendVerificationCode(email, newCode).catch((err: any) => {
                fastify.log.error(`[Auth] Resend code failed: ${err}`);
            });

            return reply.send({ success: true, message: 'Yeni aktivasyon kodu gönderildi.' });
        } catch (err: any) {
            return reply.code(500).send({ error: 'Kod gönderilemedi.' });
        }
    });

    // ══════════════════════════════════════════════════════════════════════════
    // EMAIL/PASSWORD LOGIN (sadece doğrulanmış kullanıcılar)
    // ══════════════════════════════════════════════════════════════════════════
    fastify.post('/auth/email/login', async (request, reply) => {
        try {
            const { email, password } = emailLoginSchema.parse(request.body);

            const user = await prisma.user.findUnique({ where: { email } });
            if (!user || !user.passwordHash) {
                return reply.code(401).send({ error: 'Email veya şifre hatalı.' });
            }

            const valid = await bcrypt.compare(password, user.passwordHash);
            if (!valid) {
                return reply.code(401).send({ error: 'Email veya şifre hatalı.' });
            }

            if (!user.emailVerified) {
                // Yeni kod gönder ve doğrulama ekranına yönlendir
                const newCode = generate6DigitCode();
                await prisma.user.update({
                    where: { id: user.id },
                    data: { emailVerifyToken: newCode },
                });
                sendVerificationCode(email, newCode).catch((err: any) => {
                    fastify.log.error(`[Auth] Auto-resend code failed: ${err}`);
                });

                return reply.code(403).send({
                    error: 'Email adresiniz henüz doğrulanmadı. Yeni aktivasyon kodu gönderildi.',
                    needsVerification: true,
                    emailVerified: false,
                });
            }

            if (user.status === 'BANNED') {
                return reply.code(403).send({ error: 'Bu hesap askıya alınmıştır.' });
            }

            const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
            return reply.send({ token, userId: user.id, emailVerified: true });
        } catch (err: any) {
            fastify.log.error(`Email login failed: ${err}`);
            return reply.code(400).send({ error: 'Geçersiz veri' });
        }
    });

    // ── Legacy: GET verify-email (link ile doğrulama — admin panel vb. için) ─
    fastify.get('/auth/verify-email', async (request, reply) => {
        try {
            const { token } = request.query as { token?: string };
            if (!token) return reply.code(400).send({ error: 'Token eksik.' });

            const user = await prisma.user.findUnique({ where: { emailVerifyToken: token } });
            if (!user) return reply.code(400).send({ error: 'Geçersiz token.' });

            await prisma.user.update({
                where: { id: user.id },
                data: { emailVerified: true, emailVerifyToken: null },
            });

            const appUrl = process.env.APP_URL || 'https://wacting.com';
            return reply.redirect(`${appUrl}?verified=true`);
        } catch (err: any) {
            return reply.code(500).send({ error: 'Doğrulama başarısız.' });
        }
    });

    // ── Device Register ──────────────────────────────────────────────────────
    fastify.post('/auth/register', async (request, reply) => {
        try {
            const { deviceId, username } = registerSchema.parse(request.body);

            const existing = await prisma.user.findUnique({ where: { deviceId } });
            if (existing) {
                return reply.code(409).send({ error: 'Device already registered.' });
            }

            const bonus = await getWelcomeBonus();
            const user = await prisma.user.create({
                data: {
                    deviceId,
                    icon: {
                        create: {
                            slogan: username || 'New Commander',
                            colorHex: '#007AFF',
                            shapeIndex: 0,
                            lastKnownX: 350.0,
                            lastKnownY: 350.0,
                        },
                    },
                    wac: {
                        create: {
                            wacBalance: new Prisma.Decimal(bonus.amount),
                            isActive: true,
                        },
                    },
                },
            });

            // Welcome bonus (chained tx)
            await prisma.$transaction(async (tx) => {
                await recordChainedTransaction(tx, {
                    userId: user.id,
                    amount: bonus.amount,
                    type: 'WAC_WELCOME_BONUS' as any,
                    note: bonus.note,
                });
            });

            const token = jwt.sign({ userId: user.id, deviceId }, JWT_SECRET, { expiresIn: '30d' });
            return reply.code(201).send({ token, userId: user.id });
        } catch (err: any) {
            fastify.log.error(`Registration failed: ${err}`);
            return reply.code(400).send({ error: 'Invalid payload or internal error' });
        }
    });

    // ── Device Login ─────────────────────────────────────────────────────────
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

    // ── Social Login ─────────────────────────────────────────────────────────
    fastify.post('/auth/social', async (request, reply) => {
        try {
            const { provider, providerId, email, username } = socialSchema.parse(request.body);

            const providerFieldMap: Record<string, string> = {
                google: 'googleId', facebook: 'facebookId', instagram: 'instagramId',
                twitter: 'twitterId', tiktok: 'tiktokId', linkedin: 'linkedinId',
                apple: 'appleId', steam: 'steamId',
            };
            const providerField = providerFieldMap[provider] || 'googleId';

            let user = await prisma.user.findUnique({
                where: { [providerField]: providerId } as any,
            });

            if (!user) {
                const bonus = await getWelcomeBonus();
                user = await prisma.user.create({
                    data: {
                        [providerField]: providerId,
                        email: email || null,
                        emailVerified: !!email,
                        icon: {
                            create: {
                                slogan: username || 'Social Commander',
                                colorHex: '#FF9500',
                                shapeIndex: 1,
                                lastKnownX: 350.0,
                                lastKnownY: 350.0,
                            },
                        },
                        wac: {
                            create: {
                                wacBalance: new Prisma.Decimal(bonus.amount),
                                isActive: true,
                            },
                        },
                    },
                });

                // Welcome bonus (chained tx)
                await prisma.$transaction(async (tx) => {
                    await recordChainedTransaction(tx, {
                        userId: user!.id,
                        amount: bonus.amount,
                        type: 'WAC_WELCOME_BONUS' as any,
                        note: bonus.note,
                    });
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
