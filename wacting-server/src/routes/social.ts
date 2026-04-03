import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import jwt from 'jsonwebtoken';
import { SocketManager } from '../socket/socket_manager.js';
import { refreshProfileLevel } from '../engine/profile_level_calculator.js';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key';

export async function socialRoutes(fastify: FastifyInstance) {

    fastify.addHook('preHandler', async (request, reply) => {
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

    // NLP / Vector Recommendation feed for teaming up
    fastify.get('/social/recommendations', async (request, reply) => {
        try {
            const userId = (request as any).userId;

            const me = await prisma.icon.findUnique({
                where: { userId },
                select: { slogan: true, lastKnownX: true, lastKnownY: true }
            });

            if (!me) {
                return reply.code(404).send({ error: 'Icon profile required for AI matchmaking' });
            }

            // In a production AI pipeline, we would embed me.slogan using an LLM model,
            // and perform a cosine distance sort in pgvector.
            // For now, we simulate semantic NLP clustering by finding Icons nearby geographically
            // and doing basic substring/keyword heuristic scoring.

            const candidates = await prisma.icon.findMany({
                where: { userId: { not: userId } },
                take: 100,
                include: { user: { select: { id: true, email: true, role: true } } }
            });

            // Very raw local "NLP Matchmaking" heuristic
            const scored = candidates.map((c) => {
                let score = 0;
                // Keyword overlap in Slogan
                const myWords = (me.slogan ?? '').toLowerCase().split(' ');
                const theirWords = c.slogan.toLowerCase().split(' ');
                score += myWords.filter((w: string) => theirWords.includes(w)).length * 10;

                // Geographical Clustering Proximity Match
                const dist = Math.sqrt(Math.pow(me.lastKnownX - c.lastKnownX, 2) + Math.pow(me.lastKnownY - c.lastKnownY, 2));
                score += Math.max(0, 100 - dist); // Higher score if closer

                return { ...c, aiMatchScore: score };
            });

            // Sort by highest match correlation
            const recommendations = scored.sort((a: any, b: any) => b.aiMatchScore - a.aiMatchScore).slice(0, 10);

            return reply.send({ recommendations });
        } catch (err: any) {
            fastify.log.error(`Recommendations failed: ${err}`);
            return reply.code(500).send({ error: 'NLP Matchmaking Failure' });
        }
    });

    // ----------------------------------------------------
    // SOCIAL FEATURES: Follow System
    // ----------------------------------------------------

    fastify.post('/follow', async (request, reply) => {
        try {
            const followerId = (request as any).userId;
            const { followingId } = request.body as any;

            if (followerId === followingId) return reply.code(400).send({ error: "Cannot follow yourself" });

            await prisma.$transaction(async (tx) => {
                // Create Follow Record (Pending Approval)
                await tx.follow.upsert({
                    where: { followerId_followingId: { followerId, followingId } },
                    update: { status: 'PENDING' },
                    create: { followerId, followingId, status: 'PENDING' }
                });

                // Send Notification
                const notif = await tx.notification.create({
                    data: {
                        userId: followingId,
                        type: 'FOLLOW_REQUEST',
                        title: 'Takip Istegi',
                        message: 'Birisi sizi takip etmek istiyor!'
                    }
                });
                SocketManager.notifyUser(followingId, notif);
            });

            return reply.send({ success: true, message: "Follow request sent" });
        } catch (err) {
            return reply.code(500).send({ error: 'Follow failed' });
        }
    });

    fastify.post('/unfollow', async (request, reply) => {
        try {
            const followerId = (request as any).userId;
            const { followingId } = request.body as any;

            await prisma.follow.deleteMany({
                where: { followerId, followingId }
            });

            await refreshProfileLevel(prisma, followingId);

            return reply.send({ success: true, message: "Unfollowed successfully." });
        } catch (err) {
            return reply.code(500).send({ error: 'Unfollow failed' });
        }
    });

    fastify.post('/requests/approve', async (request, reply) => {
        try {
            const followingId = (request as any).userId;
            const { followerId } = request.body as any;

            await prisma.$transaction(async (tx) => {
                const followRecord = await tx.follow.findUnique({
                    where: { followerId_followingId: { followerId, followingId } }
                });

                if (!followRecord || followRecord.status === 'APPROVED') {
                    throw new Error("Invalid request");
                }

                await tx.follow.update({
                    where: { followerId_followingId: { followerId, followingId } },
                    data: { status: 'APPROVED' }
                });

                const acceptNotif = await tx.notification.create({
                    data: {
                        userId: followerId,
                        type: 'FOLLOW_ACCEPTED',
                        title: 'Takip Onaylandi',
                        message: 'Takip isteginiz onaylandi!'
                    }
                });
                SocketManager.notifyUser(followerId, acceptNotif);
            });

            await refreshProfileLevel(prisma, followingId);

            return reply.send({ success: true });
        } catch (err) {
            return reply.code(500).send({ error: 'Approval failed' });
        }
    });

    fastify.get('/followers', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const follows = await prisma.follow.findMany({
                where: { followingId: userId, status: 'APPROVED' },
                include: { follower: { select: { id: true, avatarUrl: true, slogan: true, displayName: true } } }
            });
            return reply.send({ followers: follows });
        } catch (err) {
            return reply.code(500).send({ error: 'Failed' });
        }
    });

    fastify.get('/following', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const follows = await prisma.follow.findMany({
                where: { followerId: userId, status: 'APPROVED' },
                include: { following: { select: { id: true, avatarUrl: true, slogan: true, displayName: true } } }
            });
            return reply.send({ following: follows });
        } catch (err) {
            return reply.code(500).send({ error: 'Failed' });
        }
    });

    // ----------------------------------------------------
    // FACTION VOTING SYSTEM
    // ----------------------------------------------------

    fastify.post('/polls', async (request, reply) => {
        try {
            const commanderId = (request as any).userId;
            const { targetId, question } = request.body as any;

            if (commanderId === targetId) return reply.code(400).send({ error: "Cannot poll for yourself" });

            const poll = await prisma.poll.create({
                data: {
                    commanderId,
                    targetId,
                    question
                }
            });

            // Notify followers
            const followers = await prisma.follow.findMany({ where: { followingId: commanderId, status: 'APPROVED' } });

            for (const f of followers) {
                await prisma.notification.create({
                    data: {
                        userId: f.followerId,
                        type: 'POLL_CREATED',
                        title: 'Faction Vote Required',
                        message: `Your Commander asks: "${question}"`
                    }
                });
            }

            return reply.send({ success: true, poll });
        } catch (err) {
            return reply.code(500).send({ error: 'Poll creation failed' });
        }
    });

    // Followers check active polls created by their commanders
    fastify.get('/polls/active', async (request, reply) => {
        try {
            const userId = (request as any).userId;

            // Find users this person follows
            const following = await prisma.follow.findMany({
                where: { followerId: userId, status: 'APPROVED' },
                select: { followingId: true }
            });

            const commanderIds = following.map((f) => f.followingId);

            const activePolls = await prisma.poll.findMany({
                where: {
                    commanderId: { in: commanderIds },
                    status: 'ACTIVE'
                },
                include: {
                    commander: { select: { id: true, slogan: true } }
                }
            });

            return reply.send({ polls: activePolls });
        } catch (err) {
            return reply.code(500).send({ error: 'Failed fetching polls' });
        }
    });

    fastify.post('/polls/:id/vote', async (request, reply) => {
        try {
            const voterId = (request as any).userId;
            const pollId = (request.params as any).id;
            const { choice } = request.body as any; // boolean: true for Yes, false for No

            await prisma.$transaction(async (tx) => {
                const poll = await tx.poll.findUnique({ where: { id: pollId } });
                if (!poll || poll.status !== 'ACTIVE') throw new Error("Poll not active");

                // Verify voter is an approved follower of the commander
                const followRecord = await tx.follow.findUnique({
                    where: { followerId_followingId: { followerId: voterId, followingId: poll.commanderId } }
                });

                if (!followRecord || followRecord.status !== 'APPROVED') {
                    throw new Error("Must be an approved follower to vote in faction polls");
                }

                // Use WAC balance as vote weight
                const userWac = await tx.userWac.findUnique({ where: { userId: voterId } });
                const weight = userWac?.wacBalance ?? 0;

                await tx.vote.upsert({
                    where: { pollId_voterId: { pollId, voterId } },
                    update: { choice, weight },
                    create: { pollId, voterId, choice, weight }
                });
            });

            return reply.send({ success: true, message: "Vote cast successfully" });
        } catch (err: any) {
            return reply.code(500).send({ error: err.message || 'Voting failed' });
        }
    });
}
