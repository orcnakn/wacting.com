import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { authenticateToken } from '../middleware/auth.js';
import { SocketManager } from '../socket/socket_manager.js';

const prisma = new PrismaClient();

export async function voteRoutes(fastify: FastifyInstance) {

    fastify.addHook('onRequest', authenticateToken);

    // ─────────────────────────────────────────────────────────────────────────────
    // CREATE POLL (Campaign Leader only)
    // POST /vote/create
    // Body: { campaignId, title, description?, options: string[], durationHours: number }
    // ─────────────────────────────────────────────────────────────────────────────
    fastify.post('/create', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { campaignId, title, description, options, durationHours } = request.body as {
                campaignId: string;
                title: string;
                description?: string;
                options: string[];
                durationHours: number;
            };

            if (!campaignId) {
                return reply.status(400).send({ success: false, error: 'campaignId is required.' });
            }
            if (!title || !options || options.length < 2 || options.length > 5) {
                return reply.status(400).send({ success: false, error: 'Must provide title and 2-5 options.' });
            }

            // Verify the user is the leader of this campaign
            const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
            if (!campaign || !campaign.isActive) {
                return reply.status(404).send({ success: false, error: 'Campaign not found.' });
            }
            if (campaign.leaderId !== user.id) {
                return reply.status(403).send({ success: false, error: 'Only the campaign leader can create polls.' });
            }

            const endsAt = new Date(Date.now() + (durationHours || 24) * 3600 * 1000);

            const poll = await prisma.campaignPoll.create({
                data: {
                    campaignId,
                    title,
                    description: description ?? null,
                    endsAt,
                    options: {
                        create: options.map((text: string) => ({ text }))
                    }
                },
                include: { options: true }
            });

            fastify.log.info(`Poll created: ${poll.id} for campaign ${campaignId}`);

            // Notify all campaign members and followers
            const members = await prisma.campaignMember.findMany({
                where: { campaignId },
                select: { userId: true },
            });
            const followers = await prisma.campaignFollow.findMany({
                where: { campaignId },
                select: { userId: true },
            } as any);
            const recipientIds = new Set([
                ...members.map((m: any) => m.userId),
                ...followers.map((f: any) => f.userId),
            ]);
            recipientIds.delete(user.id); // Don't notify the creator

            const notifData = Array.from(recipientIds).map((recipientId: any) => ({
                userId: recipientId,
                type: 'POLL_CREATED' as any,
                title: 'Yeni Oylama',
                message: `${campaign.title} kampanyasinda yeni oylama baslatildi`,
                body: `${campaign.title} kampanyasinda yeni oylama baslatildi`,
                data: JSON.stringify({ pollId: poll.id, campaignId }),
            }));

            if (notifData.length > 0) {
                await prisma.notification.createMany({ data: notifData });
                // Real-time push
                for (const recipientId of recipientIds) {
                    SocketManager.notifyUser(recipientId as string, {
                        type: 'POLL_CREATED',
                        title: 'Yeni Oylama',
                        message: `${campaign.title} kampanyasinda yeni oylama baslatildi`,
                    });
                }
            }

            return reply.send({ success: true, poll });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: error.message || 'Failed to create poll' });
        }
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // GET POLLS FOR A CAMPAIGN
    // GET /vote/campaign/:campaignId
    // Privacy: RAC protestors CANNOT see campaign polls (tokenomics rule)
    // ─────────────────────────────────────────────────────────────────────────────
    fastify.get('/campaign/:campaignId', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { campaignId } = request.params as { campaignId: string };

            const polls = await prisma.campaignPoll.findMany({
                where: { campaignId },
                orderBy: { createdAt: 'desc' },
                include: {
                    options: {
                        include: { votes: true }
                    },
                    votes: true
                }
            });

            const enriched = polls.map((poll: any) => ({
                ...poll,
                options: poll.options.map((opt: any) => ({
                    ...opt,
                    voterCount: opt.votes.length,
                    totalWac: opt.votes.reduce((sum: number, v: any) => sum + parseFloat(v.wacWeight || 0), 0)
                })),
                totalVoters: poll.votes.length
            }));

            return reply.send({ success: true, polls: enriched });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch polls' });
        }
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // CAST A VOTE
    // POST /vote/:pollId/vote
    // Body: { optionId }
    // Rules:
    //   - Only WAC stakers (campaign members) can vote
    //   - RAC protestors CANNOT vote in campaign polls
    //   - Vote weight = member's stakedWac in that campaign
    // ─────────────────────────────────────────────────────────────────────────────
    fastify.post('/:pollId/vote', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { pollId } = request.params as { pollId: string };
            const { optionId } = request.body as { optionId: string };

            const poll = await prisma.campaignPoll.findUnique({ where: { id: pollId } });
            if (!poll || poll.status !== 'ACTIVE') {
                return reply.status(400).send({ success: false, error: 'Poll is not active' });
            }
            if (new Date() > new Date(poll.endsAt)) {
                return reply.status(400).send({ success: false, error: 'Poll has expired' });
            }

            // Must be a campaign member (WAC staker) to vote
            const member = await (prisma as any).campaignMember.findUnique({
                where: { campaignId_userId: { campaignId: poll.campaignId, userId: user.id } },
            });
            if (!member) {
                return reply.status(403).send({
                    success: false,
                    error: 'Yalnızca kampanya üyeleri (WAC stake sahipleri) oy kullanabilir.',
                });
            }

            // Vote weight = member's staked WAC
            const wacWeight = member.stakedWac ?? 1;

            const vote = await prisma.pollVote.create({
                data: { pollId, optionId, voterId: user.id, wacWeight }
            });

            return reply.send({ success: true, vote });
        } catch (error: any) {
            if (error.code === 'P2002') {
                return reply.status(409).send({ success: false, error: 'You have already voted in this poll.' });
            }
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to cast vote' });
        }
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // CLOSE A POLL (Leader only)
    // POST /vote/:pollId/close
    // ─────────────────────────────────────────────────────────────────────────────
    fastify.post('/:pollId/close', async (request, reply) => {
        try {
            const user = (request as any).user;
            const { pollId } = request.params as { pollId: string };

            const poll = await prisma.campaignPoll.findUnique({
                where: { id: pollId },
                include: {
                    campaign: true,
                    options: { include: { votes: true } }
                }
            });

            if (!poll) {
                return reply.status(404).send({ success: false, error: 'Poll not found' });
            }
            if (poll.campaign.leaderId !== user.id) {
                return reply.status(403).send({ success: false, error: 'Only the campaign leader can close polls' });
            }

            let winnerOption = poll.options[0];
            let maxWac = 0;
            for (const opt of poll.options) {
                const total = opt.votes.reduce((sum: number, v: any) => sum + parseFloat(v.wacWeight || 0), 0);
                if (total > maxWac) { maxWac = total; winnerOption = opt; }
            }

            const updated = await prisma.campaignPoll.update({
                where: { id: pollId },
                data: { status: 'COMPLETED', winnerOption: winnerOption?.text ?? null }
            });

            // Notify all voters of poll result
            const voterIds = await prisma.pollVote.findMany({
                where: { pollId },
                select: { voterId: true },
            });
            const closeNotifData = voterIds.map((v: any) => ({
                userId: v.voterId,
                type: 'POLL_CLOSED' as any,
                title: 'Oylama Sonuclandi',
                message: `${poll.title} oylamasi tamamlandi. Kazanan: ${winnerOption?.text ?? '-'}`,
                body: `${poll.title} oylamasi tamamlandi. Kazanan: ${winnerOption?.text ?? '-'}`,
                data: JSON.stringify({ pollId, campaignId: poll.campaignId, winner: winnerOption?.text }),
            }));
            if (closeNotifData.length > 0) {
                await prisma.notification.createMany({ data: closeNotifData });
            }

            return reply.send({ success: true, winner: winnerOption?.text, poll: updated });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to close poll' });
        }
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // GET USER'S VOTING HISTORY
    // GET /vote/history
    // ─────────────────────────────────────────────────────────────────────────────
    fastify.get('/history', async (request, reply) => {
        try {
            const user = (request as any).user;
            const userVotes = await prisma.pollVote.findMany({
                where: { voterId: user.id },
                orderBy: { createdAt: 'desc' },
                include: {
                    option: true,
                    poll: {
                        include: { options: { include: { votes: true } } }
                    }
                }
            });

            const history = userVotes.map((v: any) => {
                const poll = v.poll;
                const myOption = v.option.text;
                const winner = poll.winnerOption;
                const isActive = poll.status === 'ACTIVE';
                return {
                    pollId: poll.id,
                    pollTitle: poll.title,
                    campaignId: poll.campaignId,
                    myChoice: myOption,
                    winnerOption: winner,
                    status: poll.status,
                    endsAt: poll.endsAt,
                    result: isActive ? 'Devam Ediyor' : (winner === myOption ? 'Kazandı' : 'Kaybetti')
                };
            });

            return reply.send({ success: true, history });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch voting history' });
        }
    });
}
