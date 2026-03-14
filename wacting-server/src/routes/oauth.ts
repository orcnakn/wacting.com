import { FastifyInstance } from 'fastify';
import { PrismaClient, Prisma } from '@prisma/client';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';
const BASE_URL = process.env.APP_URL || 'http://localhost:3000';

// Provider OAuth configurations
interface OAuthConfig {
    authUrl: string;
    tokenUrl: string;
    profileUrl: string;
    clientId: string;
    clientSecret: string;
    scope: string;
    providerField: string; // Prisma User field name
}

function getProviderConfig(provider: string): OAuthConfig | null {
    const configs: Record<string, OAuthConfig> = {
        google: {
            authUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
            tokenUrl: 'https://oauth2.googleapis.com/token',
            profileUrl: 'https://www.googleapis.com/oauth2/v2/userinfo',
            clientId: process.env.GOOGLE_CLIENT_ID || '',
            clientSecret: process.env.GOOGLE_CLIENT_SECRET || '',
            scope: 'openid email profile',
            providerField: 'googleId',
        },
        facebook: {
            authUrl: 'https://www.facebook.com/v19.0/dialog/oauth',
            tokenUrl: 'https://graph.facebook.com/v19.0/oauth/access_token',
            profileUrl: 'https://graph.facebook.com/me?fields=id,name,email',
            clientId: process.env.FACEBOOK_CLIENT_ID || '',
            clientSecret: process.env.FACEBOOK_CLIENT_SECRET || '',
            scope: 'email,public_profile',
            providerField: 'facebookId',
        },
        instagram: {
            authUrl: 'https://www.facebook.com/v19.0/dialog/oauth',
            tokenUrl: 'https://graph.facebook.com/v19.0/oauth/access_token',
            profileUrl: 'https://graph.facebook.com/me?fields=id,name,email',
            clientId: process.env.INSTAGRAM_CLIENT_ID || '',
            clientSecret: process.env.INSTAGRAM_CLIENT_SECRET || '',
            scope: 'email,public_profile,instagram_basic',
            providerField: 'instagramId',
        },
        twitter: {
            authUrl: 'https://twitter.com/i/oauth2/authorize',
            tokenUrl: 'https://api.twitter.com/2/oauth2/token',
            profileUrl: 'https://api.twitter.com/2/users/me',
            clientId: process.env.TWITTER_CLIENT_ID || '',
            clientSecret: process.env.TWITTER_CLIENT_SECRET || '',
            scope: 'tweet.read users.read offline.access',
            providerField: 'twitterId',
        },
        tiktok: {
            authUrl: 'https://www.tiktok.com/v2/auth/authorize/',
            tokenUrl: 'https://open.tiktokapis.com/v2/oauth/token/',
            profileUrl: 'https://open.tiktokapis.com/v2/user/info/',
            clientId: process.env.TIKTOK_CLIENT_ID || '',
            clientSecret: process.env.TIKTOK_CLIENT_SECRET || '',
            scope: 'user.info.basic',
            providerField: 'tiktokId',
        },
        linkedin: {
            authUrl: 'https://www.linkedin.com/oauth/v2/authorization',
            tokenUrl: 'https://www.linkedin.com/oauth/v2/accessToken',
            profileUrl: 'https://api.linkedin.com/v2/userinfo',
            clientId: process.env.LINKEDIN_CLIENT_ID || '',
            clientSecret: process.env.LINKEDIN_CLIENT_SECRET || '',
            scope: 'openid profile email',
            providerField: 'linkedinId',
        },
        apple: {
            authUrl: 'https://appleid.apple.com/auth/authorize',
            tokenUrl: 'https://appleid.apple.com/auth/token',
            profileUrl: '', // Apple returns user info in the ID token
            clientId: process.env.APPLE_CLIENT_ID || '',
            clientSecret: process.env.APPLE_CLIENT_SECRET || '',
            scope: 'name email',
            providerField: 'appleId',
        },
        steam: {
            // Steam uses OpenID 2.0
            authUrl: 'https://steamcommunity.com/openid/login',
            tokenUrl: '', // not used for OpenID
            profileUrl: 'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/',
            clientId: process.env.STEAM_API_KEY || '',
            clientSecret: '',
            scope: '',
            providerField: 'steamId',
        },
    };

    return configs[provider] || null;
}

// Store PKCE verifiers and state tokens temporarily (in production use Redis)
const stateStore = new Map<string, { provider: string; codeVerifier?: string }>();

export async function oauthRoutes(fastify: FastifyInstance) {

    // ══════════════════════════════════════════════════════════════════════════
    // START OAuth — redirect to provider
    // ══════════════════════════════════════════════════════════════════════════
    fastify.get('/auth/oauth/start/:provider', async (request, reply) => {
        const { provider } = request.params as { provider: string };
        const config = getProviderConfig(provider);

        if (!config) {
            return reply.code(400).send({ error: `Unknown provider: ${provider}` });
        }

        if (!config.clientId) {
            return reply.code(501).send({ error: `${provider} login is not configured yet.` });
        }

        const state = crypto.randomBytes(16).toString('hex');
        const redirectUri = `${BASE_URL}/auth/oauth/callback/${provider}`;

        // Steam uses OpenID 2.0 — different flow
        if (provider === 'steam') {
            const params = new URLSearchParams({
                'openid.ns': 'http://specs.openid.net/auth/2.0',
                'openid.mode': 'checkid_setup',
                'openid.return_to': `${redirectUri}?state=${state}`,
                'openid.realm': BASE_URL,
                'openid.identity': 'http://specs.openid.net/auth/2.0/identifier_select',
                'openid.claimed_id': 'http://specs.openid.net/auth/2.0/identifier_select',
            });
            stateStore.set(state, { provider });
            return reply.redirect(`${config.authUrl}?${params.toString()}`);
        }

        // Twitter uses PKCE
        let codeVerifier: string | undefined;
        let codeChallenge: string | undefined;
        if (provider === 'twitter') {
            codeVerifier = crypto.randomBytes(32).toString('base64url');
            codeChallenge = crypto.createHash('sha256').update(codeVerifier).digest('base64url');
        }

        stateStore.set(state, { provider, codeVerifier });

        const params = new URLSearchParams({
            client_id: config.clientId,
            redirect_uri: redirectUri,
            response_type: 'code',
            scope: config.scope,
            state,
        });

        // TikTok uses client_key instead of client_id
        if (provider === 'tiktok') {
            params.delete('client_id');
            params.set('client_key', config.clientId);
        }

        // Apple needs response_mode=form_post
        if (provider === 'apple') {
            params.set('response_mode', 'form_post');
        }

        // Twitter PKCE
        if (provider === 'twitter' && codeChallenge) {
            params.set('code_challenge', codeChallenge);
            params.set('code_challenge_method', 'S256');
        }

        return reply.redirect(`${config.authUrl}?${params.toString()}`);
    });

    // ══════════════════════════════════════════════════════════════════════════
    // CALLBACK — exchange code for profile, create/find user, return JWT
    // ══════════════════════════════════════════════════════════════════════════
    fastify.get('/auth/oauth/callback/:provider', async (request, reply) => {
        const { provider } = request.params as { provider: string };
        const query = request.query as Record<string, string>;
        const config = getProviderConfig(provider);

        if (!config) {
            return sendResult(reply, null, `Unknown provider: ${provider}`);
        }

        const state = query.state || query['openid.state'];
        const stored = state ? stateStore.get(state) : null;
        if (state) stateStore.delete(state);

        try {
            let providerId: string;
            let email: string | undefined;
            let displayName: string | undefined;

            if (provider === 'steam') {
                // Verify Steam OpenID and extract Steam ID
                const claimedId = query['openid.claimed_id'] || '';
                const steamIdMatch = claimedId.match(/\/id\/(\d+)$/);
                if (!steamIdMatch) throw new Error('Invalid Steam response');
                providerId = steamIdMatch[1]!;

                // Fetch Steam profile
                if (config.clientId) {
                    try {
                        const profileRes = await fetch(
                            `${config.profileUrl}?key=${config.clientId}&steamids=${providerId}`
                        );
                        const profileData = await profileRes.json() as any;
                        const player = profileData?.response?.players?.[0];
                        if (player) {
                            displayName = player.personaname;
                        }
                    } catch {}
                }
            } else {
                // Standard OAuth 2.0 code exchange
                const code = query.code;
                if (!code) throw new Error('No authorization code received');

                const redirectUri = `${BASE_URL}/auth/oauth/callback/${provider}`;

                // Exchange code for access token
                const tokenBody: Record<string, string> = {
                    grant_type: 'authorization_code',
                    code,
                    redirect_uri: redirectUri,
                    client_id: config.clientId,
                    client_secret: config.clientSecret,
                };

                if (provider === 'tiktok') {
                    tokenBody.client_key = config.clientId;
                }

                if (provider === 'twitter' && stored?.codeVerifier) {
                    tokenBody.code_verifier = stored.codeVerifier;
                }

                const headers: Record<string, string> = {
                    'Content-Type': 'application/x-www-form-urlencoded',
                };

                // Twitter uses Basic auth for token exchange
                if (provider === 'twitter') {
                    headers['Authorization'] = 'Basic ' + Buffer.from(
                        `${config.clientId}:${config.clientSecret}`
                    ).toString('base64');
                    delete tokenBody.client_id;
                    delete tokenBody.client_secret;
                }

                const tokenRes = await fetch(config.tokenUrl, {
                    method: 'POST',
                    headers,
                    body: new URLSearchParams(tokenBody).toString(),
                });
                const tokenData = await tokenRes.json() as any;
                const accessToken = tokenData.access_token;

                if (!accessToken) throw new Error('Failed to get access token');

                // Fetch user profile
                if (provider === 'apple') {
                    // Apple: decode ID token
                    const idToken = tokenData.id_token;
                    if (idToken) {
                        const payload = JSON.parse(
                            Buffer.from(idToken.split('.')[1], 'base64').toString()
                        );
                        providerId = payload.sub;
                        email = payload.email;
                    } else {
                        throw new Error('No ID token from Apple');
                    }
                } else if (provider === 'tiktok') {
                    const profileRes = await fetch(config.profileUrl, {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${accessToken}`,
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({ fields: ['open_id', 'display_name', 'avatar_url'] }),
                    });
                    const profileData = await profileRes.json() as any;
                    providerId = profileData.data?.user?.open_id || tokenData.open_id;
                    displayName = profileData.data?.user?.display_name;
                } else {
                    // Google, Facebook, Instagram, LinkedIn, Twitter
                    const profileRes = await fetch(config.profileUrl, {
                        headers: { 'Authorization': `Bearer ${accessToken}` },
                    });
                    const profile = await profileRes.json() as any;

                    if (provider === 'twitter') {
                        providerId = profile.data?.id;
                        displayName = profile.data?.name;
                    } else if (provider === 'linkedin') {
                        providerId = profile.sub;
                        email = profile.email;
                        displayName = profile.name;
                    } else {
                        // Google, Facebook, Instagram
                        providerId = profile.id;
                        email = profile.email;
                        displayName = profile.name;
                    }
                }
            }

            if (!providerId!) throw new Error('Could not get provider user ID');

            // Find or create user
            let user = await prisma.user.findUnique({
                where: { [config.providerField]: providerId } as any,
            });

            if (!user) {
                user = await prisma.user.create({
                    data: {
                        [config.providerField]: providerId,
                        email: email || null,
                        emailVerified: !!email,
                        slogan: displayName || `${provider} user`,
                        icon: {
                            create: {
                                slogan: displayName || 'Social Commander',
                                colorHex: '#FF9500',
                                shapeIndex: 1,
                                lastKnownX: 350.0,
                                lastKnownY: 350.0,
                            },
                        },
                        wac: {
                            create: {
                                wacBalance: new Prisma.Decimal('1.000000'),
                                isActive: true,
                            },
                        },
                    },
                });

                await prisma.transaction.create({
                    data: {
                        userId: user.id,
                        amount: new Prisma.Decimal('1.000000'),
                        type: 'WAC_DEPOSIT',
                        note: 'Welcome bonus: 1 WAC on social registration',
                    },
                });
            }

            const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
            return sendResult(reply, { token, userId: user.id });

        } catch (err: any) {
            fastify.log.error(`OAuth callback failed for ${provider}: ${err.message}`);
            return sendResult(reply, null, err.message || 'Authentication failed');
        }
    });

    // Apple sends callback as POST (form_post response mode)
    fastify.post('/auth/oauth/callback/apple', async (request, reply) => {
        const body = request.body as Record<string, string>;
        // Rewrite as query params and forward to GET handler
        const query = new URLSearchParams(body).toString();
        return reply.redirect(`/auth/oauth/callback/apple?${query}`);
    });
}

// Send result back to opener window via postMessage
function sendResult(reply: any, data: any, error?: string) {
    const message = error
        ? JSON.stringify({ error })
        : JSON.stringify(data);

    return reply.type('text/html').send(`
<!DOCTYPE html>
<html>
<head><title>Wacting - Login</title></head>
<body>
<script>
    if (window.opener) {
        window.opener.postMessage(${JSON.stringify(message)}, '*');
        window.close();
    } else {
        document.body.innerText = 'Giris basarili! Bu pencereyi kapatabilirsiniz.';
    }
</script>
<p>Giris isleniyor...</p>
</body>
</html>
    `);
}
