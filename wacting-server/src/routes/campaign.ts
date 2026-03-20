/**
 * campaign.ts — Campaign Routes with WAC Staking Tokenomics
 *
 * POST /campaign/create      — Create campaign (costs 1 WAC stake)
 * POST /campaign/:id/join     — Join campaign with WAC stake
 * POST /campaign/:id/leave    — Leave campaign (30% penalty: 15% burn + 15% dev, 2x RAC mint)
 * POST /campaign/:id/stake    — Add more WAC to existing membership
 * POST /campaign/:id/pin      — Pin campaign leader to map location
 * GET  /campaign/:id          — Get single campaign
 * GET  /campaign/:id/members  — Get campaign members
 * GET  /campaign/mine         — List my campaigns
 * GET  /campaign/all          — List all active campaigns
 * GET  /campaign/nearby       — List nearby campaigns
 * GET  /campaign/popular      — List popular campaigns
 * GET  /campaign/trending     — List trending campaigns
 */

import { FastifyInstance } from 'fastify';
import { PrismaClient, Prisma } from '@prisma/client';
import { authenticateToken } from '../middleware/auth.js';
import { recordChainedTransaction } from '../engine/chain_engine.js';
import { GRID_WIDTH, GRID_HEIGHT } from '../utils/brownian.js';

const prisma = new PrismaClient();
const MIN_STAKE = new Prisma.Decimal('1.000000'); // Minimum WAC to join/create

const STANCE_COLORS: Record<string, string> = {
    PROTEST: '#FF4444',
    SUPPORT: '#4CAF50',
    REFORM: '#2196F3',
    EMERGENCY: '#FF9800',
};

export async function campaignRoutes(fastify: FastifyInstance) {

    // All campaign routes require authentication
    fastify.addHook('onRequest', authenticateToken);

    // ── Create Campaign ──────────────────────────────────────────────────────
    fastify.post('/create', async (request, reply) => {
        try {
            const user = (request as any).user;
            const body = request.body as {
                title: string;
                slogan: string;
                description?: string;
                videoUrl?: string;
                iconColor: string;
                iconShape: number;
                speed?: number;
                stakeAmount?: string;
                instagramUrl?: string;
                twitterUrl?: string;
                facebookUrl?: string;
                tiktokUrl?: string;
                websiteUrl?: string;
                stanceType: string;
                categoryType: string;
            };

            if (!body.title || !body.slogan) {
                return reply.status(400).send({ success: false, error: 'Title and slogan are required.' });
            }

            if (!body.stanceType || !['PROTEST', 'SUPPORT', 'REFORM', 'EMERGENCY'].includes(body.stanceType)) {
                return reply.status(400).send({ success: false, error: 'Valid stanceType required.' });
            }
            if (!body.categoryType || !['GLOBAL_PEACE', 'JUSTICE_RIGHTS', 'ECOLOGY_NATURE', 'TECH_FUTURE', 'SOLIDARITY_RELIEF', 'ECONOMY_LABOR', 'AWARENESS', 'ENTERTAINMENT'].includes(body.categoryType)) {
                return reply.status(400).send({ success: false, error: 'Valid categoryType required.' });
            }

            if (body.speed !== undefined && (body.speed < 0 || body.speed > 1)) {
                return reply.status(400).send({ success: false, error: 'Speed must be between 0 and 1.' });
            }

            const stakeAmount = new Prisma.Decimal(body.stakeAmount || '1.000000');
            if (stakeAmount.lt(MIN_STAKE)) {
                return reply.status(400).send({
                    success: false,
                    error: `Kampanya oluşturmak için en az ${MIN_STAKE} WAC gerekli.`,
                });
            }

            // Check WAC balance
            const userWac = await prisma.userWac.findUnique({ where: { userId: user.id } });
            if (!userWac || !userWac.isActive || userWac.wacBalance.lt(stakeAmount)) {
                return reply.status(400).send({
                    success: false,
                    error: 'Yetersiz WAC bakiyesi.',
                    requiredWac: stakeAmount.toFixed(6),
                    currentWac: userWac?.wacBalance.toFixed(6) ?? '0.000000',
                });
            }

            // Atomic: deduct WAC, create campaign, add leader as member with stake
            const campaign = await prisma.$transaction(async (tx) => {
                // Deduct WAC from user balance
                await tx.userWac.update({
                    where: { userId: user.id },
                    data: {
                        wacBalance: { decrement: stakeAmount },
                        balanceUpdatedAt: new Date(),
                    },
                });

                // Create campaign with initial WAC staked
                const c = await (tx as any).campaign.create({
                    data: {
                        leaderId: user.id,
                        title: body.title,
                        slogan: body.slogan,
                        description: body.description ?? null,
                        videoUrl: body.videoUrl ?? null,
                        iconColor: STANCE_COLORS[body.stanceType] || body.iconColor || '#2C3E50',
                        iconShape: body.iconShape ?? 0,
                        speed: body.speed ?? 0.5,
                        instagramUrl: body.instagramUrl ?? null,
                        twitterUrl: body.twitterUrl ?? null,
                        facebookUrl: body.facebookUrl ?? null,
                        tiktokUrl: body.tiktokUrl ?? null,
                        websiteUrl: body.websiteUrl ?? null,
                        stanceType: body.stanceType as any,
                        categoryType: body.categoryType as any,
                        totalWacStaked: stakeAmount,
                    },
                });

                // Leader is first member with stake
                await (tx as any).campaignMember.create({
                    data: {
                        campaignId: c.id,
                        userId: user.id,
                        stakedWac: stakeAmount,
                    },
                });

                // Update icon appearance
                await tx.icon.updateMany({
                    where: { userId: user.id },
                    data: {
                        colorHex: STANCE_COLORS[body.stanceType] || body.iconColor || '#2C3E50',
                        shapeIndex: body.iconShape ?? 0,
                        slogan: body.slogan.substring(0, 50),
                    },
                });

                // Chained transaction record
                await recordChainedTransaction(tx, {
                    userId: user.id,
                    amount: stakeAmount,
                    type: 'WAC_CAMPAIGN_STAKE' as any,
                    note: `Campaign created: "${body.title}" — staked ${stakeAmount} WAC`,
                    campaignId: c.id,
                });

                return c;
            });

            const updatedWac = await prisma.userWac.findUnique({ where: { userId: user.id } });

            return reply.code(201).send({
                success: true,
                campaign,
                wacBalance: updatedWac?.wacBalance.toFixed(6) ?? '0.000000',
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: error.message || 'Failed to create campaign' });
        }
    });

    // ── Join Campaign (with WAC stake) ───────────────────────────────────────
    fastify.post('/:id/join', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { id } = request.params as { id: string };
            const body = request.body as { stakeAmount?: string };

            const stakeAmount = new Prisma.Decimal(body?.stakeAmount || '1.000000');
            if (stakeAmount.lt(MIN_STAKE)) {
                return reply.status(400).send({
                    success: false,
                    error: `Kampanyaya katılmak için en az ${MIN_STAKE} WAC gerekli.`,
                });
            }

            const campaign = await prisma.campaign.findUnique({ where: { id } });
            if (!campaign || !campaign.isActive) {
                return reply.status(404).send({ success: false, error: 'Campaign not found.' });
            }

            const existing = await (prisma as any).campaignMember.findUnique({
                where: { campaignId_userId: { campaignId: id, userId: user.id } },
            });
            if (existing) {
                return reply.status(409).send({ success: false, error: 'Already a member of this campaign.' });
            }

            // Check WAC balance
            const userWac = await prisma.userWac.findUnique({ where: { userId: user.id } });
            if (!userWac || !userWac.isActive || userWac.wacBalance.lt(stakeAmount)) {
                return reply.status(400).send({
                    success: false,
                    error: 'Yetersiz WAC bakiyesi.',
                    requiredWac: stakeAmount.toFixed(6),
                    currentWac: userWac?.wacBalance.toFixed(6) ?? '0.000000',
                });
            }

            await prisma.$transaction(async (tx) => {
                // Deduct WAC from user
                await tx.userWac.update({
                    where: { userId: user.id },
                    data: {
                        wacBalance: { decrement: stakeAmount },
                        balanceUpdatedAt: new Date(),
                    },
                });

                // Add member with stake
                await (tx as any).campaignMember.create({
                    data: {
                        campaignId: id,
                        userId: user.id,
                        stakedWac: stakeAmount,
                    },
                });

                // Update campaign total staked
                await tx.campaign.update({
                    where: { id },
                    data: { totalWacStaked: { increment: stakeAmount } },
                });

                // Chained transaction record
                await recordChainedTransaction(tx, {
                    userId: user.id,
                    amount: stakeAmount,
                    type: 'WAC_CAMPAIGN_STAKE' as any,
                    note: `Joined campaign "${campaign.title}" — staked ${stakeAmount} WAC`,
                    campaignId: id,
                });
            });

            return reply.send({
                success: true,
                message: 'Kampanyaya başarıyla katıldınız.',
                stakedWac: stakeAmount.toFixed(6),
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: error.message || 'Failed to join campaign' });
        }
    });

    // ── Add More Stake ────────────────────────────────────────────────────────
    fastify.post('/:id/stake', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { id } = request.params as { id: string };
            const body = request.body as { amount: string };

            const amount = new Prisma.Decimal(body.amount);
            if (amount.lte(0)) {
                return reply.status(400).send({ success: false, error: 'Amount must be > 0' });
            }

            const member = await (prisma as any).campaignMember.findUnique({
                where: { campaignId_userId: { campaignId: id, userId: user.id } },
            });
            if (!member) {
                return reply.status(404).send({ success: false, error: 'Bu kampanyanın üyesi değilsiniz.' });
            }

            const userWac = await prisma.userWac.findUnique({ where: { userId: user.id } });
            if (!userWac || userWac.wacBalance.lt(amount)) {
                return reply.status(400).send({ success: false, error: 'Yetersiz WAC bakiyesi.' });
            }

            await prisma.$transaction(async (tx) => {
                await tx.userWac.update({
                    where: { userId: user.id },
                    data: {
                        wacBalance: { decrement: amount },
                        balanceUpdatedAt: new Date(),
                    },
                });

                await (tx as any).campaignMember.update({
                    where: { campaignId_userId: { campaignId: id, userId: user.id } },
                    data: { stakedWac: { increment: amount } },
                });

                await tx.campaign.update({
                    where: { id },
                    data: { totalWacStaked: { increment: amount } },
                });

                await recordChainedTransaction(tx, {
                    userId: user.id,
                    amount,
                    type: 'WAC_CAMPAIGN_STAKE' as any,
                    note: `Added ${amount} WAC stake to campaign`,
                    campaignId: id,
                });
            });

            return reply.send({ success: true, message: 'Stake eklendi.' });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: error.message || 'Failed to add stake' });
        }
    });

    // ── Leave Campaign (with 30% penalty + RAC mint) ─────────────────────────
    fastify.post('/:id/leave', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { id } = request.params as { id: string };

            const campaign = await prisma.campaign.findUnique({
                where: { id },
                include: {
                    members: {
                        orderBy: { joinedAt: 'asc' },
                        include: { user: true },
                    },
                },
            });

            if (!campaign || !campaign.isActive) {
                return reply.status(404).send({ success: false, error: 'Campaign not found.' });
            }

            const member = campaign.members.find((m) => m.userId === user.id);
            if (!member) {
                return reply.status(404).send({ success: false, error: 'Bu kampanyanın üyesi değilsiniz.' });
            }

            const stakedWac = member.stakedWac;
            const isLeader = campaign.leaderId === user.id;
            const memberCount = campaign.members.length;

            // Tokenomics: 30% penalty, 70% return, 2x penalty as RAC
            const penalty = stakedWac.mul('0.30').toDecimalPlaces(6);
            const returnAmount = stakedWac.mul('0.70').toDecimalPlaces(6);
            const burnAmount = penalty.mul('0.50').toDecimalPlaces(6);   // 15% of total
            const devAmount = penalty.sub(burnAmount);                    // 15% of total
            const racReward = BigInt(penalty.mul('2').floor().toFixed(0)); // 2x penalty as RAC

            await prisma.$transaction(async (tx) => {
                // 1. Remove member
                await (tx as any).campaignMember.delete({
                    where: { campaignId_userId: { campaignId: id, userId: user.id } },
                });

                // 2. Decrease campaign staked WAC
                await tx.campaign.update({
                    where: { id },
                    data: { totalWacStaked: { decrement: stakedWac } },
                });

                // 3. Return 70% WAC to user
                await tx.userWac.upsert({
                    where: { userId: user.id },
                    update: {
                        wacBalance: { increment: returnAmount },
                        balanceUpdatedAt: new Date(),
                        isActive: true,
                    },
                    create: {
                        userId: user.id,
                        wacBalance: returnAmount,
                        isActive: true,
                    },
                });

                // 4. Burn 15% + Dev 15%
                await tx.treasury.upsert({
                    where: { id: 'singleton' },
                    update: {
                        burnedTotal: { increment: burnAmount },
                        devBalance: { increment: devAmount },
                    },
                    create: {
                        id: 'singleton',
                        burnedTotal: burnAmount,
                        devBalance: devAmount,
                    },
                });

                // 5. Mint RAC to user (2x penalty)
                if (racReward > 0n) {
                    await tx.userRac.upsert({
                        where: { userId: user.id },
                        update: { racBalance: { increment: racReward } },
                        create: { userId: user.id, racBalance: racReward },
                    });
                }

                // 6. Record chained transactions (4 legs)
                await recordChainedTransaction(tx, {
                    userId: user.id,
                    amount: returnAmount,
                    type: 'WAC_CAMPAIGN_RETURN' as any,
                    note: `Campaign exit — 70% of ${stakedWac.toFixed(6)} WAC returned`,
                    campaignId: id,
                });

                await recordChainedTransaction(tx, {
                    userId: user.id,
                    amount: burnAmount,
                    type: 'WAC_BURN' as any,
                    note: `Campaign exit — 15% burned (${burnAmount.toFixed(6)} WAC)`,
                    campaignId: id,
                });

                await recordChainedTransaction(tx, {
                    userId: user.id,
                    amount: devAmount,
                    type: 'WAC_DEV_FEE' as any,
                    note: `Campaign exit — 15% dev fee (${devAmount.toFixed(6)} WAC)`,
                    campaignId: id,
                });

                await recordChainedTransaction(tx, {
                    userId: user.id,
                    amount: racReward.toString(),
                    type: 'RAC_MINTED' as any,
                    note: `Campaign exit — ${racReward} RAC minted (2x penalty)`,
                    campaignId: id,
                });

                // 7. Record history
                await (tx as any).campaignHistory.create({
                    data: {
                        userId: user.id,
                        campaignId: id,
                        joinedAt: member.joinedAt,
                        totalEarned: returnAmount,
                    },
                });

                // 8. Leader succession
                if (isLeader) {
                    if (memberCount <= 1) {
                        await tx.campaign.update({
                            where: { id },
                            data: { isActive: false },
                        });
                    } else {
                        const successor = campaign.members.find((m) => m.userId !== user.id);
                        if (successor) {
                            await tx.campaign.update({
                                where: { id },
                                data: { leaderId: successor.userId },
                            });
                            fastify.log.info(`[Campaign] Leader succession: ${user.id} → ${successor.userId} for campaign ${id}`);
                        }
                    }
                }
            });

            fastify.log.info(
                `[Campaign] ${user.id} left campaign ${id}. ` +
                `Returned: ${returnAmount}, Burned: ${burnAmount}, Dev: ${devAmount}, RAC: ${racReward}`
            );

            return reply.send({
                success: true,
                totalStaked: stakedWac.toFixed(6),
                returned: returnAmount.toFixed(6),
                burned: burnAmount.toFixed(6),
                devFee: devAmount.toFixed(6),
                racMinted: Number(racReward),
                message: isLeader && memberCount <= 1
                    ? 'Kampanya kapatıldı — üye kalmadı.'
                    : isLeader
                        ? 'Kampanyadan ayrıldınız. Liderlik devredildi.'
                        : 'Kampanyadan ayrıldınız. WAC iadeniz ve RAC ödülünüz hesabınıza aktarıldı.',
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: error.message || 'Failed to leave campaign' });
        }
    });

    // ── Pin Campaign Location (Leader Only) ──────────────────────────────────
    fastify.post('/:id/pin', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { id } = request.params as { id: string };
            const body = request.body as { lat: number; lng: number } | null;

            const campaign = await prisma.campaign.findUnique({ where: { id } });
            if (!campaign || !campaign.isActive) {
                return reply.status(404).send({ success: false, error: 'Kampanya bulunamadı.' });
            }
            if (campaign.leaderId !== user.id) {
                return reply.status(403).send({ success: false, error: 'Sadece kampanya lideri konum sabitleyebilir.' });
            }

            // Helper: convert lat/lng to grid coords
            const lngToGridX = (lng: number) => (lng + 180) / 360 * GRID_WIDTH;
            const latToGridY = (lat: number) => (90 - lat) / 180 * GRID_HEIGHT;

            // Access movement engine for real-time update
            const engine = (fastify as any).engine;

            if (!body || body.lat === undefined || body.lng === undefined) {
                // Unpin
                await prisma.campaign.update({
                    where: { id },
                    data: { pinnedLat: null, pinnedLng: null },
                });
                // Update engine in real-time
                if (engine) {
                    const icon = engine.icons.get(user.id);
                    if (icon) {
                        icon.pinnedX = null;
                        icon.pinnedY = null;
                    }
                }
                return reply.send({ success: true, message: 'Konum sabitleme kaldırıldı.', pinnedLat: null, pinnedLng: null });
            }

            const { lat, lng } = body;
            if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
                return reply.status(400).send({ success: false, error: 'Geçersiz koordinat.' });
            }

            await prisma.campaign.update({
                where: { id },
                data: { pinnedLat: lat, pinnedLng: lng },
            });

            // Update engine in real-time
            const gridX = lngToGridX(lng);
            const gridY = latToGridY(lat);
            if (engine) {
                const icon = engine.icons.get(user.id);
                if (icon) {
                    icon.pinnedX = gridX;
                    icon.pinnedY = gridY;
                    icon.x = gridX;
                    icon.y = gridY;
                    icon.isCampaignLeader = true;
                }
            }

            return reply.send({
                success: true,
                message: 'Konum sabitlendi.',
                pinnedLat: lat,
                pinnedLng: lng,
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: error.message || 'Failed to pin location' });
        }
    });

    // ── Update Campaign Speed (Leader Only) ──────────────────────────────────
    fastify.post('/:id/speed', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { id } = request.params as { id: string };
            const body = request.body as { speed: number };

            const campaign = await prisma.campaign.findUnique({ where: { id } });
            if (!campaign || !campaign.isActive) {
                return reply.status(404).send({ success: false, error: 'Kampanya bulunamadı.' });
            }
            if (campaign.leaderId !== user.id) {
                return reply.status(403).send({ success: false, error: 'Sadece kampanya lideri hızı değiştirebilir.' });
            }

            const speed = body.speed;
            if (speed === undefined || speed < 0 || speed > 1) {
                return reply.status(400).send({ success: false, error: 'Hız 0-1 arasında olmalı.' });
            }

            await prisma.campaign.update({
                where: { id },
                data: { speed },
            });

            // Update all campaign member icons in the engine
            const engine = (fastify as any).engine;
            if (engine) {
                const members = await (prisma as any).campaignMember.findMany({
                    where: { campaignId: id },
                    select: { userId: true },
                });
                for (const m of members) {
                    const icon = engine.icons.get(m.userId);
                    if (icon) {
                        icon.campaignSpeed = speed;
                    }
                }
            }

            return reply.send({ success: true, speed, message: 'Kampanya hızı güncellendi.' });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: error.message || 'Failed to update speed' });
        }
    });

    // ── Get Campaign Members ──────────────────────────────────────────────────
    fastify.get('/:id/members', async (request, reply) => {
        try {
            const { id } = request.params as { id: string };

            const campaign = await prisma.campaign.findUnique({
                where: { id },
                include: {
                    members: {
                        orderBy: { joinedAt: 'asc' },
                        include: {
                            user: {
                                select: { id: true, slogan: true, avatarUrl: true, email: true },
                            },
                        },
                    },
                },
            });

            if (!campaign) {
                return reply.status(404).send({ success: false, error: 'Campaign not found.' });
            }

            const members = campaign.members.map((m) => ({
                userId: m.userId,
                joinedAt: m.joinedAt,
                isLeader: m.userId === campaign.leaderId,
                stakedWac: m.stakedWac.toFixed(6),
                user: m.user,
            }));

            return reply.send({
                success: true,
                members,
                leaderUserId: campaign.leaderId,
                totalWacStaked: campaign.totalWacStaked.toFixed(6),
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch members' });
        }
    });

    // ── List My Campaigns ────────────────────────────────────────────────────
    fastify.get('/mine', async (request, reply) => {
        try {
            const user = (request as any).user;

            // Campaigns where I'm a member (not just leader)
            const memberships = await (prisma as any).campaignMember.findMany({
                where: { userId: user.id },
                include: {
                    campaign: {
                        include: {
                            leader: { select: { id: true, slogan: true, avatarUrl: true } },
                            _count: { select: { members: true, polls: true } },
                        },
                    },
                },
                orderBy: { joinedAt: 'desc' },
            });

            const campaigns = memberships.map((m: any) => ({
                ...m.campaign,
                myStakedWac: m.stakedWac.toFixed(6),
                isLeader: m.campaign.leaderId === user.id,
                memberCount: m.campaign._count.members,
            }));

            return reply.send({ success: true, campaigns });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch campaigns' });
        }
    });

    // ── List All Active Campaigns ─────────────────────────────────────────────
    fastify.get('/all', async (_request, reply) => {
        try {
            const campaigns = await prisma.campaign.findMany({
                where: { isActive: true },
                orderBy: { totalWacStaked: 'desc' },
                take: 50,
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    _count: { select: { members: true, polls: true } },
                },
            });

            const enriched = campaigns.map((c) => ({
                ...c,
                totalWacStaked: c.totalWacStaked.toFixed(6),
                memberCount: c._count.members,
                pollCount: c._count.polls,
            }));

            return reply.send({ success: true, campaigns: enriched });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch campaigns' });
        }
    });

    // ── Get Single Campaign ───────────────────────────────────────────────────
    fastify.get('/:id', async (request, reply) => {
        try {
            const { id } = request.params as { id: string };
            const campaign = await prisma.campaign.findUnique({
                where: { id },
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    racPool: { select: { totalBalance: true, participantCount: true, isActive: true } },
                    _count: { select: { members: true, polls: true } },
                },
            });
            if (!campaign) {
                return reply.status(404).send({ success: false, error: 'Campaign not found' });
            }

            // Icon size = totalWacStaked - racPool
            const racPoolBalance = campaign.racPool ? Number(campaign.racPool.totalBalance) : 0;
            const effectiveSize = Math.max(0, Number(campaign.totalWacStaked) - racPoolBalance);

            return reply.send({
                success: true,
                campaign: {
                    ...campaign,
                    totalWacStaked: campaign.totalWacStaked.toFixed(6),
                    effectiveSize,
                    racPool: campaign.racPool
                        ? {
                            totalBalance: Number(campaign.racPool.totalBalance),
                            participantCount: campaign.racPool.participantCount,
                            isActive: campaign.racPool.isActive,
                        }
                        : null,
                },
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Server error' });
        }
    });

    // ── Helper: Calculate distance between two points (Haversine formula) ──────
    const calcDistance = (x1: number, y1: number, x2: number, y2: number): number => {
        const R = 6371;
        const dLat = (y2 - y1) * (Math.PI / 180);
        const dLon = (x2 - x1) * (Math.PI / 180);
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                  Math.cos(y1 * (Math.PI / 180)) * Math.cos(y2 * (Math.PI / 180)) *
                  Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    };

    // ── List Nearby Campaigns (by user location) ───────────────────────────────
    fastify.get('/nearby', async (request, reply) => {
        try {
            const user = (request as any).user;
            const userIcon = await prisma.icon.findUnique({ where: { userId: user.id } });
            if (!userIcon) {
                return reply.send({ success: true, campaigns: [] });
            }

            const userX = userIcon.lastKnownX;
            const userY = userIcon.lastKnownY;
            const radiusKm = 100;

            const campaigns = await prisma.campaign.findMany({
                where: { isActive: true },
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    members: { include: { user: { include: { icon: true } } } },
                    _count: { select: { polls: true } },
                },
            });

            const nearby = campaigns
                .filter((c) =>
                    c.members.some((m) => {
                        const icon = m.user.icon;
                        if (!icon) return false;
                        return calcDistance(userX, userY, icon.lastKnownX, icon.lastKnownY) <= radiusKm;
                    })
                )
                .slice(0, 20)
                .map((c) => ({
                    ...c,
                    totalWacStaked: c.totalWacStaked.toFixed(6),
                    memberCount: c.members.length,
                    pollCount: c._count.polls,
                }));

            return reply.send({ success: true, campaigns: nearby });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch nearby campaigns' });
        }
    });

    // ── List Popular Campaigns (by total WAC staked) ────────────────────────────
    fastify.get('/popular', async (_request, reply) => {
        try {
            const campaigns = await prisma.campaign.findMany({
                where: { isActive: true },
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    _count: { select: { members: true, polls: true } },
                },
                orderBy: { totalWacStaked: 'desc' },
                take: 20,
            });

            const enriched = campaigns.map((c) => ({
                ...c,
                totalWacStaked: c.totalWacStaked.toFixed(6),
                memberCount: c._count.members,
                pollCount: c._count.polls,
            }));

            return reply.send({ success: true, campaigns: enriched });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch popular campaigns' });
        }
    });

    // ── List Trending Campaigns (by poll reactions) ───────────────────────────
    fastify.get('/trending', async (_request, reply) => {
        try {
            const campaigns = await prisma.campaign.findMany({
                where: { isActive: true },
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    polls: { include: { _count: { select: { votes: true } } } },
                    _count: { select: { members: true, polls: true } },
                },
            });

            const trending = campaigns
                .map((c) => ({
                    campaign: c,
                    totalVotes: c.polls.reduce((sum, p) => sum + p._count.votes, 0),
                }))
                .sort((a, b) => b.totalVotes - a.totalVotes)
                .slice(0, 20)
                .map((item) => ({
                    ...item.campaign,
                    totalWacStaked: item.campaign.totalWacStaked.toFixed(6),
                    memberCount: item.campaign._count.members,
                    pollCount: item.campaign._count.polls,
                    totalVotes: item.totalVotes,
                }));

            return reply.send({ success: true, campaigns: trending });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch trending campaigns' });
        }
    });

    // ── List Lynched Campaigns (highest RAC protest pool) ────────────────────
    fastify.get('/lynched', async (_request, reply) => {
        try {
            const pools = await (prisma as any).racPool.findMany({
                where: { isActive: true },
                orderBy: { totalBalance: 'desc' },
                take: 20,
                include: {
                    targetCampaign: {
                        include: {
                            leader: { select: { id: true, slogan: true, avatarUrl: true } },
                            _count: { select: { members: true, polls: true } },
                        },
                    },
                },
            });

            const campaigns = pools
                .filter((p: any) => p.targetCampaign?.isActive)
                .map((p: any) => ({
                    ...p.targetCampaign,
                    totalWacStaked: p.targetCampaign.totalWacStaked.toFixed(6),
                    memberCount: p.targetCampaign._count.members,
                    pollCount: p.targetCampaign._count.polls,
                    racPoolBalance: Number(p.totalBalance),
                    racParticipantCount: p.participantCount,
                }));

            return reply.send({ success: true, campaigns });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch lynched campaigns' });
        }
    });

    // ── List Newest Campaigns ────────────────────────────────────────────────
    fastify.get('/newest', async (_request, reply) => {
        try {
            const campaigns = await prisma.campaign.findMany({
                where: { isActive: true },
                orderBy: { createdAt: 'desc' },
                take: 20,
                include: {
                    leader: { select: { id: true, slogan: true, avatarUrl: true } },
                    _count: { select: { members: true, polls: true } },
                },
            });

            const enriched = campaigns.map((c) => ({
                ...c,
                totalWacStaked: c.totalWacStaked.toFixed(6),
                memberCount: c._count.members,
                pollCount: c._count.polls,
            }));

            return reply.send({ success: true, campaigns: enriched });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch newest campaigns' });
        }
    });
}
