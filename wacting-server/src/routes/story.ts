import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export async function storyRoutes(fastify: FastifyInstance) {

    // POST /story — Create a new story
    fastify.post('/', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const { content, mediaUrl, mediaType, youtubeUrl } = request.body as any;

            if (!content && !mediaUrl && !youtubeUrl) {
                return reply.code(400).send({ error: 'Story must have content, media, or a YouTube link' });
            }

            const story = await prisma.story.create({
                data: {
                    userId,
                    content: content || null,
                    mediaUrl: mediaUrl || null,
                    mediaType: mediaType || null,
                    youtubeUrl: youtubeUrl || null,
                },
            });

            return reply.send({ success: true, story });
        } catch (err: any) {
            fastify.log.error(`Story create failed: ${err}`);
            return reply.code(500).send({ error: 'Failed to create story' });
        }
    });

    // GET /story/mine — Get my stories
    fastify.get('/mine', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const stories = await prisma.story.findMany({
                where: { userId },
                orderBy: { createdAt: 'desc' },
            });
            return reply.send({ success: true, stories });
        } catch (err: any) {
            fastify.log.error(`Story fetch failed: ${err}`);
            return reply.code(500).send({ error: 'Failed to fetch stories' });
        }
    });

    // GET /story/user/:userId — Get stories for a user's profile
    fastify.get('/user/:userId', async (request, reply) => {
        try {
            const { userId } = request.params as any;
            const stories = await prisma.story.findMany({
                where: { userId },
                orderBy: { createdAt: 'desc' },
            });
            return reply.send({ success: true, stories });
        } catch (err: any) {
            fastify.log.error(`Story fetch failed: ${err}`);
            return reply.code(500).send({ error: 'Failed to fetch stories' });
        }
    });

    // PUT /story/:id — Update a story
    fastify.put('/:id', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const { id } = request.params as any;
            const { content, mediaUrl, mediaType, youtubeUrl } = request.body as any;

            const story = await prisma.story.findUnique({ where: { id } });
            if (!story || story.userId !== userId) {
                return reply.code(403).send({ error: 'Not authorized' });
            }

            const updated = await prisma.story.update({
                where: { id },
                data: {
                    ...(content !== undefined ? { content } : {}),
                    ...(mediaUrl !== undefined ? { mediaUrl } : {}),
                    ...(mediaType !== undefined ? { mediaType } : {}),
                    ...(youtubeUrl !== undefined ? { youtubeUrl } : {}),
                },
            });

            return reply.send({ success: true, story: updated });
        } catch (err: any) {
            fastify.log.error(`Story update failed: ${err}`);
            return reply.code(500).send({ error: 'Failed to update story' });
        }
    });

    // DELETE /story/:id — Delete a story
    fastify.delete('/:id', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const { id } = request.params as any;

            const story = await prisma.story.findUnique({ where: { id } });
            if (!story || story.userId !== userId) {
                return reply.code(403).send({ error: 'Not authorized' });
            }

            await prisma.story.delete({ where: { id } });

            // Check if user has any remaining published stories
            const remaining = await prisma.story.count({
                where: { userId, isPublished: true },
            });
            if (remaining === 0) {
                await prisma.icon.updateMany({
                    where: { userId },
                    data: { hasPublishedStory: false },
                });
            }

            return reply.send({ success: true });
        } catch (err: any) {
            fastify.log.error(`Story delete failed: ${err}`);
            return reply.code(500).send({ error: 'Failed to delete story' });
        }
    });

    // POST /story/:id/publish — Publish a story + select platforms
    fastify.post('/:id/publish', async (request, reply) => {
        try {
            const userId = (request as any).userId;
            const { id } = request.params as any;
            const { platforms } = request.body as any; // string[] e.g. ["instagram", "twitter"]

            const story = await prisma.story.findUnique({ where: { id } });
            if (!story || story.userId !== userId) {
                return reply.code(403).send({ error: 'Not authorized' });
            }

            const updated = await prisma.story.update({
                where: { id },
                data: {
                    isPublished: true,
                    publishedTo: platforms || [],
                },
            });

            // Set hasPublishedStory on the user's icon
            await prisma.icon.updateMany({
                where: { userId },
                data: { hasPublishedStory: true },
            });

            return reply.send({ success: true, story: updated });
        } catch (err: any) {
            fastify.log.error(`Story publish failed: ${err}`);
            return reply.code(500).send({ error: 'Failed to publish story' });
        }
    });
}
