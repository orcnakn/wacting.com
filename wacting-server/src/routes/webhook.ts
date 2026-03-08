import { FastifyInstance } from 'fastify';
import { PrismaClient, TxType } from '@prisma/client';

const prisma = new PrismaClient();

// In production, you would retrieve this from RevenueCat dashboard
const REVENUECAT_WEBHOOK_AUTH_TOKEN = 'mock_revenuecat_auth_key';

export async function webhookRoutes(fastify: FastifyInstance) {

    fastify.post('/webhooks/revenuecat', async (request, reply) => {
        // 1. Authenticate the incoming webhook
        const authHeader = request.headers.authorization;
        if (authHeader !== `Bearer ${REVENUECAT_WEBHOOK_AUTH_TOKEN}`) {
            fastify.log.warn('Unauthorized RevenueCat webhook attempt');
            return reply.code(401).send({ error: 'Unauthorized' });
        }

        const payload = request.body as any;
        const event = payload.event;

        // 2. We only care about successful initial purchases or renewals of token bundles
        if (event.type === 'INITIAL_PURCHASE' || event.type === 'NON_RENEWING_PURCHASE') {
            const appUserId = event.app_user_id; // The User ID we sent from Flutter
            const productId = event.product_id;  // e.g. 'wacting_tokens_1000'

            let tokenAmount = 0;

            // Determine bundle size
            switch (productId) {
                case 'wact_starter': tokenAmount = 1000; break;
                case 'wact_growth': tokenAmount = 5500; break;
                case 'wact_dominator': tokenAmount = 12000; break;
                case 'wact_whale': tokenAmount = 25000; break;
                default:
                    fastify.log.error(`Unknown product ID purchased: ${productId}`);
                    return reply.code(200).send(); // Ack to prevent RC retries
            }

            try {
                // 3. Perform a Prisma Transaction to safely add tokens and log the ledger event
                await prisma.$transaction(async (tx) => {
                    // Add tokens to wallet
                    await tx.user.update({
                        where: { id: appUserId },
                        data: {
                            tokens: { increment: tokenAmount }
                        }
                    });

                    // Create ledger trail
                    await tx.transaction.create({
                        data: {
                            userId: appUserId,
                            amount: tokenAmount,
                            type: TxType.PURCHASE_BUNDLE
                        }
                    });
                });

                fastify.log.info(`Securely vaulted ${tokenAmount} WAC tokens for user ${appUserId}`);

            } catch (err) {
                fastify.log.error(`Failed to process RevenueCat DB transaction: ${err}`);
                return reply.code(500).send();
            }
        }

        // Always acknowledge RevenueCat events with 200 OK so it doesn't retry forever
        return reply.code(200).send({ status: 'ok' });
    });
}
