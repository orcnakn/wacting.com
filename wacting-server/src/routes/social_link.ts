/**
 * social_link.ts
 *
 * Authenticated social-account linking (separate from login OAuth).
 * A logged-in user can connect their Instagram (and later other platforms)
 * to their Wacting profile to auto-populate username and follower count.
 *
 * Flow:
 *   1. Flutter opens popup:  GET /auth/link/instagram?token=<JWT>
 *   2. Server stores {userId, provider} in stateStore, redirects to Instagram OAuth
 *   3. Instagram redirects to:  GET /auth/link/instagram/callback?code=...&state=...
 *   4. Server exchanges code → access_token → fetches username
 *   5. Updates user's instagramUrl + instagramId in DB
 *   6. Returns HTML that calls window.opener.postMessage({success, username}) and closes
 *
 * Instagram Basic Display API:
 *   - Gives us: id, username, account_type
 *   - Does NOT give follower count (that requires Graph API + Business account)
 *   - Follower count can be entered manually in the follow-up dialog
 *
 * Environment variables required:
 *   INSTAGRAM_CLIENT_ID       — Instagram App ID from Meta Developer Console
 *   INSTAGRAM_CLIENT_SECRET   — Instagram App Secret
 *   APP_URL                   — Public base URL e.g. https://wacting.com
 */

import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { refreshProfileLevel } from '../engine/profile_level_calculator.js';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';
const BASE_URL = (process.env.APP_URL || 'http://localhost:3000').replace(/\/$/, '');

// In-memory state store: state → { userId, provider }
// In production replace with Redis with TTL
const linkStateStore = new Map<string, { userId: string; provider: string }>();

// Clean up stale states every 10 minutes
setInterval(() => {
    // Simple cleanup: if store grows large, clear oldest half
    if (linkStateStore.size > 500) {
        const keys = [...linkStateStore.keys()];
        keys.slice(0, 250).forEach(k => linkStateStore.delete(k));
    }
}, 10 * 60 * 1000);

// ─── Provider Configurations ────────────────────────────────────────────────

interface LinkProviderConfig {
    authUrl: string;
    tokenUrl: string;
    profileUrl: string;
    clientId: string;
    clientSecret: string;
    scope: string;
    /** Field on User model to store provider ID */
    idField: string;
    /** Field on User model to store profile URL */
    urlField: string;
    /** Field on User model to store follower count */
    followerField: string;
    /** Base profile URL to construct full URL from username */
    profileBaseUrl: string;
}

function getLinkConfig(provider: string): LinkProviderConfig | null {
    const configs: Record<string, LinkProviderConfig> = {
        instagram: {
            authUrl: 'https://api.instagram.com/oauth/authorize',
            tokenUrl: 'https://api.instagram.com/oauth/access_token',
            profileUrl: 'https://graph.instagram.com/me?fields=id,username,account_type',
            clientId: process.env.INSTAGRAM_CLIENT_ID || '',
            clientSecret: process.env.INSTAGRAM_CLIENT_SECRET || '',
            scope: 'user_profile',
            idField: 'instagramId',
            urlField: 'instagramUrl',
            followerField: 'instagramFollowers',
            profileBaseUrl: 'https://instagram.com/',
        },
        twitter: {
            authUrl: 'https://twitter.com/i/oauth2/authorize',
            tokenUrl: 'https://api.twitter.com/2/oauth2/token',
            profileUrl: 'https://api.twitter.com/2/users/me?user.fields=public_metrics',
            clientId: process.env.TWITTER_CLIENT_ID || '',
            clientSecret: process.env.TWITTER_CLIENT_SECRET || '',
            scope: 'tweet.read users.read offline.access',
            idField: 'twitterId',
            urlField: 'twitterUrl',
            followerField: 'twitterFollowers',
            profileBaseUrl: 'https://x.com/',
        },
        tiktok: {
            authUrl: 'https://www.tiktok.com/v2/auth/authorize/',
            tokenUrl: 'https://open.tiktokapis.com/v2/oauth/token/',
            profileUrl: 'https://open.tiktokapis.com/v2/user/info/?fields=open_id,display_name,username,follower_count',
            clientId: process.env.TIKTOK_CLIENT_ID || '',
            clientSecret: process.env.TIKTOK_CLIENT_SECRET || '',
            scope: 'user.info.basic',
            idField: 'tiktokId',
            urlField: 'tiktokUrl',
            followerField: 'tiktokFollowers',
            profileBaseUrl: 'https://tiktok.com/@',
        },
    };
    return configs[provider] || null;
}

// ─── Route Handler ───────────────────────────────────────────────────────────

export async function socialLinkRoutes(fastify: FastifyInstance) {

    // ── STEP 1: Initiate link — called from Flutter popup ────────────────────
    // GET /auth/link/:provider?token=<JWT>
    fastify.get('/auth/link/:provider', async (request, reply) => {
        const { provider } = request.params as { provider: string };
        const { token } = request.query as { token?: string };

        if (!token) {
            return reply.type('text/html').send(errorPage('Kimlik doğrulama tokeni eksik.'));
        }

        let userId: string;
        try {
            const payload = jwt.verify(token, JWT_SECRET) as { userId: string };
            userId = payload.userId;
        } catch {
            return reply.type('text/html').send(errorPage('Geçersiz veya süresi dolmuş token.'));
        }

        const config = getLinkConfig(provider);
        if (!config) {
            return reply.type('text/html').send(errorPage(`Desteklenmeyen platform: ${provider}`));
        }

        if (!config.clientId) {
            return reply.type('text/html').send(errorPage(
                `${provider} bağlantısı henüz yapılandırılmamış. ` +
                `Lütfen ${provider.toUpperCase()}_CLIENT_ID ortam değişkenini ayarlayın.`
            ));
        }

        const state = crypto.randomBytes(16).toString('hex');
        linkStateStore.set(state, { userId, provider });

        const redirectUri = `${BASE_URL}/auth/link/${provider}/callback`;

        const params = new URLSearchParams({
            client_id: config.clientId,
            redirect_uri: redirectUri,
            response_type: 'code',
            scope: config.scope,
            state,
        });

        // TikTok uses client_key
        if (provider === 'tiktok') {
            params.delete('client_id');
            params.set('client_key', config.clientId);
        }

        // Twitter needs PKCE — simplified here (store verifier in state)
        if (provider === 'twitter') {
            const codeVerifier = crypto.randomBytes(32).toString('base64url');
            const codeChallenge = crypto.createHash('sha256').update(codeVerifier).digest('base64url');
            (linkStateStore.get(state) as any).codeVerifier = codeVerifier;
            params.set('code_challenge', codeChallenge);
            params.set('code_challenge_method', 'S256');
        }

        return reply.redirect(`${config.authUrl}?${params.toString()}`);
    });

    // ── STEP 2: OAuth Callback ────────────────────────────────────────────────
    // GET /auth/link/:provider/callback?code=...&state=...
    fastify.get('/auth/link/:provider/callback', async (request, reply) => {
        const { provider } = request.params as { provider: string };
        const { code, state, error } = request.query as Record<string, string>;

        if (error) {
            return reply.type('text/html').send(linkResult({ error: `Instagram izin vermedi: ${error}` }));
        }

        const stored = state ? linkStateStore.get(state) : null;
        if (state) linkStateStore.delete(state);

        if (!stored || stored.provider !== provider) {
            return reply.type('text/html').send(linkResult({ error: 'Geçersiz state parametresi. Lütfen tekrar deneyin.' }));
        }

        const config = getLinkConfig(provider);
        if (!config || !code) {
            return reply.type('text/html').send(linkResult({ error: 'Yetkilendirme kodu alınamadı.' }));
        }

        try {
            const redirectUri = `${BASE_URL}/auth/link/${provider}/callback`;

            // Exchange code for access token
            const tokenBody: Record<string, string> = {
                client_id: config.clientId,
                client_secret: config.clientSecret,
                grant_type: 'authorization_code',
                redirect_uri: redirectUri,
                code,
            };

            const tokenHeaders: Record<string, string> = {
                'Content-Type': 'application/x-www-form-urlencoded',
            };

            // Twitter: Basic auth + PKCE
            if (provider === 'twitter') {
                tokenHeaders['Authorization'] = 'Basic ' + Buffer.from(
                    `${config.clientId}:${config.clientSecret}`
                ).toString('base64');
                delete tokenBody.client_id;
                delete tokenBody.client_secret;
                const codeVerifier = (stored as any).codeVerifier;
                if (codeVerifier) tokenBody.code_verifier = codeVerifier;
            }

            const tokenRes = await fetch(config.tokenUrl, {
                method: 'POST',
                headers: tokenHeaders,
                body: new URLSearchParams(tokenBody).toString(),
            });
            const tokenData = await tokenRes.json() as any;
            const accessToken = tokenData.access_token;

            if (!accessToken) {
                fastify.log.error(`Link token exchange failed for ${provider}:`, tokenData);
                throw new Error('Access token alınamadı.');
            }

            // Fetch profile
            let providerId: string;
            let username: string;
            let followerCount: number | undefined;

            if (provider === 'instagram') {
                const profileRes = await fetch(
                    `${config.profileUrl}&access_token=${accessToken}`
                );
                const profile = await profileRes.json() as any;
                if (!profile.id) throw new Error('Instagram profil bilgisi alınamadı.');
                providerId = profile.id as string;
                username = (profile.username as string) || providerId;

            } else if (provider === 'twitter') {
                const profileRes = await fetch(config.profileUrl, {
                    headers: { 'Authorization': `Bearer ${accessToken}` },
                });
                const profile = await profileRes.json() as any;
                providerId = profile.data?.id as string;
                username = profile.data?.username as string;
                followerCount = profile.data?.public_metrics?.followers_count as number | undefined;

            } else if (provider === 'tiktok') {
                const profileRes = await fetch(config.profileUrl, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${accessToken}`,
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ fields: ['open_id', 'display_name', 'username', 'follower_count'] }),
                });
                const profile = await profileRes.json() as any;
                providerId = profile.data?.user?.open_id || tokenData.open_id;
                username = profile.data?.user?.username || profile.data?.user?.display_name;
                followerCount = profile.data?.user?.follower_count;

            } else {
                throw new Error(`Desteklenmeyen platform: ${provider}`);
            }

            if (!providerId! || !username!) throw new Error('Kullanıcı bilgisi alınamadı.');

            // Check if this Instagram account is already linked to another user
            const existing = await (prisma as any).user.findUnique({
                where: { [config.idField]: providerId },
                select: { id: true },
            });
            if (existing && existing.id !== stored.userId) {
                return reply.type('text/html').send(linkResult({
                    error: 'Bu Instagram hesabı başka bir Wacting hesabına bağlı.',
                }));
            }

            // Build profile URL
            const profileUrl = `${config.profileBaseUrl}${username}`;

            // Update user
            const updateData: Record<string, any> = {
                [config.idField]: providerId,
                [config.urlField]: profileUrl,
            };
            if (followerCount !== undefined && followerCount > 0) {
                updateData[config.followerField] = followerCount;
            }

            await (prisma as any).user.update({
                where: { id: stored.userId },
                data: updateData,
            });

            // Refresh profile level (follower count may have changed)
            await refreshProfileLevel(prisma, stored.userId);

            return reply.type('text/html').send(linkResult({
                success: true,
                provider,
                username,
                profileUrl,
                followerCount,
            }));

        } catch (err: any) {
            fastify.log.error(`Social link failed for ${provider}: ${err.message}`);
            return reply.type('text/html').send(linkResult({ error: err.message || 'Bağlantı başarısız oldu.' }));
        }
    });

    // ── Unlink endpoint ───────────────────────────────────────────────────────
    // DELETE /auth/link/:provider  (authenticated via header)
    fastify.delete('/auth/link/:provider', async (request, reply) => {
        const { provider } = request.params as { provider: string };
        const authHeader = request.headers.authorization;
        const token = authHeader?.replace('Bearer ', '');

        if (!token) return reply.code(401).send({ error: 'Unauthorized' });

        let userId: string;
        try {
            const payload = jwt.verify(token, JWT_SECRET) as { userId: string };
            userId = payload.userId;
        } catch {
            return reply.code(401).send({ error: 'Invalid token' });
        }

        const config = getLinkConfig(provider);
        if (!config) return reply.code(400).send({ error: 'Unknown provider' });

        await (prisma as any).user.update({
            where: { id: userId },
            data: {
                [config.idField]: null,
                [config.urlField]: null,
            },
        });

        return reply.send({ success: true });
    });
}

// ─── HTML Helpers ────────────────────────────────────────────────────────────

function linkResult(data: {
    success?: boolean;
    provider?: string;
    username?: string;
    profileUrl?: string;
    followerCount?: number;
    error?: string;
}): string {
    const message = JSON.stringify(data);
    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Wacting — Platform Bağlama</title>
  <style>
    body { font-family: system-ui, sans-serif; display: flex; align-items: center;
           justify-content: center; height: 100vh; margin: 0;
           background: ${data.error ? '#FFF0F0' : '#F0FFF4'}; }
    .box { text-align: center; padding: 32px; border-radius: 16px;
           background: white; box-shadow: 0 4px 24px rgba(0,0,0,.08); max-width: 320px; }
    h2 { margin: 0 0 12px; color: ${data.error ? '#E53E3E' : '#38A169'}; font-size: 20px; }
    p  { color: #555; font-size: 14px; }
  </style>
</head>
<body>
  <div class="box">
    <h2>${data.error ? '❌ Bağlantı Başarısız' : '✅ Bağlantı Başarılı!'}</h2>
    <p>${data.error || `@${data.username} hesabı bağlandı.`}</p>
    <p style="font-size:12px;color:#aaa">Bu pencere otomatik kapanacak...</p>
  </div>
  <script>
    const msg = ${message};
    if (window.opener) {
      window.opener.postMessage(JSON.stringify({ wactingLink: msg }), '*');
      setTimeout(() => window.close(), 1500);
    }
  </script>
</body>
</html>`;
}

function errorPage(message: string): string {
    return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Hata</title></head>
<body style="font-family:system-ui;display:flex;align-items:center;justify-content:center;height:100vh;background:#FFF0F0">
  <div style="text-align:center;padding:32px;background:white;border-radius:16px;box-shadow:0 4px 24px rgba(0,0,0,.08)">
    <h2 style="color:#E53E3E">❌ Hata</h2>
    <p style="color:#555">${message}</p>
  </div>
  <script>
    if (window.opener) {
      window.opener.postMessage(JSON.stringify({ wactingLink: { error: ${JSON.stringify(message)} } }), '*');
      setTimeout(() => window.close(), 3000);
    }
  </script>
</body>
</html>`;
}
