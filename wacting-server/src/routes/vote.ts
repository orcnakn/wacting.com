import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export async function voteRoutes(fastify: FastifyInstance) {

    // ─────────────────────────────────────────────────────────────────────────────
    // CREATE POLL (Campaign Leader only)
    // POST /vote/create
    // Body: { title, description?, options: string[], durationHours: number }
    // ─────────────────────────────────────────────────────────────────────────────
    fastify.post('/create', async (request, reply) => {
        try {
            const user = (request as any).user || { id: 'mockLeaderId_1' };
            const { title, description, options, durationHours } = request.body as {
                title: string;
                description?: string;
                options: string[];
                durationHours: number;
            };

            if (!title || !options || options.length < 2 || options.length > 5) {
                return reply.status(400).send({ success: false, error: 'Must provide 2-5 options.' });
            }

            const endsAt = new Date(Date.now() + (durationHours || 24) * 3600 * 1000);

            const poll = await (prisma as any).campaignPoll.create({
                data: {
                    campaignId: user.id,
                    title,
                    description: description ?? null,
                    endsAt,
                    options: {
                        create: options.map((text: string) => ({ text }))
                    }
                },
                include: { options: true }
            });

            // Notify all followers / WAC participants
            // TODO: Replace with actual participant lookup once DB is live
            fastify.log.info(`Poll created: ${poll.id} — notifications would be sent to participants`);

            return reply.send({ success: true, poll });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to create poll' });
        }
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // GET POLLS FOR A CAMPAIGN
    // GET /vote/campaign/:campaignId
    // ─────────────────────────────────────────────────────────────────────────────
    fastify.get('/campaign/:campaignId', async (request, reply) => {
        try {
            const { campaignId } = request.params as { campaignId: string };
            const polls = await (prisma as any).campaignPoll.findMany({
                where: { campaignId },
                orderBy: { createdAt: 'desc' },
                include: {
                    options: {
                        include: {
                            votes: true
                        }
                    },
                    votes: true
                }
            });

            // Enrich with WAC totals and voter count per option
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
    // ─────────────────────────────────────────────────────────────────────────────
    fastify.post('/:pollId/vote', async (request, reply) => {
        try {
            const user = (request as any).user || { id: 'mockVoterId_1' };
            const { pollId } = request.params as { pollId: string };
            const { optionId } = request.body as { optionId: string };

            // Check poll is still active
            const poll = await (prisma as any).campaignPoll.findUnique({
                where: { id: pollId }
            });
            if (!poll || poll.status !== 'ACTIVE') {
                return reply.status(400).send({ success: false, error: 'Poll is not active' });
            }
            if (new Date() > new Date(poll.endsAt)) {
                return reply.status(400).send({ success: false, error: 'Poll has expired' });
            }

            // Get user's current WAC balance as vote weight
            const wacRecord = await prisma.userWac.findUnique({
                where: { userId: user.id }
            });
            const wacWeight = wacRecord?.wacBalance ?? 1; // Default weight 1 if no WAC

            const vote = await (prisma as any).pollVote.create({
                data: {
                    pollId,
                    optionId,
                    voterId: user.id,
                    wacWeight
                }
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
            const user = (request as any).user || { id: 'mockLeaderId_1' };
            const { pollId } = request.params as { pollId: string };

            const poll = await (prisma as any).campaignPoll.findUnique({
                where: { id: pollId },
                include: { options: { include: { votes: true } } }
            });

            if (!poll || poll.campaignId !== user.id) {
                return reply.status(403).send({ success: false, error: 'Not authorized or poll not found' });
            }

            // Calculate winner by WAC weight
            let winnerOption = poll.options[0];
            let maxWac = 0;
            for (const opt of poll.options) {
                const total = opt.votes.reduce((sum: number, v: any) => sum + parseFloat(v.wacWeight || 0), 0);
                if (total > maxWac) {
                    maxWac = total;
                    winnerOption = opt;
                }
            }

            const updated = await (prisma as any).campaignPoll.update({
                where: { id: pollId },
                data: {
                    status: 'COMPLETED',
                    winnerOption: winnerOption?.text ?? null
                }
            });

            return reply.send({ success: true, winner: winnerOption?.text, poll: updated });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to close poll' });
        }
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // GET USER'S VOTING HISTORY (for "Oylama Geçmişi" tab)
    // GET /vote/history
    // ─────────────────────────────────────────────────────────────────────────────
    fastify.get('/history', async (request, reply) => {
        try {
            const user = (request as any).user || { id: 'mockVoterId_1' };
            const userVotes = await (prisma as any).pollVote.findMany({
                where: { voterId: user.id },
                orderBy: { createdAt: 'desc' },
                include: {
                    option: true,
                    poll: {
                        include: {
                            options: {
                                include: { votes: true }
                            }
                        }
                    }
                }
            });

            const history = userVotes.map((v: any) => {
                const poll = v.poll;
                const myOption = v.option.text;
                const winner = poll.winnerOption;
                const isActive = poll.status === 'ACTIVE';
                const didWin = winner === myOption;
                return {
                    pollId: poll.id,
                    pollTitle: poll.title,
                    campaignId: poll.campaignId,
                    myChoice: myOption,
                    winnerOption: winner,
                    status: poll.status,
                    endsAt: poll.endsAt,
                    result: isActive ? 'Devam Ediyor' : (didWin ? 'Kazandı' : 'Kaybetti')
                };
            });

            return reply.send({ success: true, history });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.status(500).send({ success: false, error: 'Failed to fetch voting history' });
        }
    });
}
