import { FastifyInstance } from 'fastify';
import { PrismaClient, Prisma } from '@prisma/client';

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

        // 2. We only care about successful initial purchases or renewals of WAC bundles
        if (event.type === 'INITIAL_PURCHASE' || event.type === 'NON_RENEWING_PURCHASE') {
            const appUserId = event.app_user_id; // The User ID we sent from Flutter
            const productId = event.product_id;  // e.g. 'wact_starter'

            let wacAmount = 0;

            // Determine bundle size
            switch (productId) {
                case 'wact_starter': wacAmount = 1000; break;
                case 'wact_growth': wacAmount = 5500; break;
                case 'wact_dominator': wacAmount = 12000; break;
                case 'wact_whale': wacAmount = 25000; break;
                default:
                    fastify.log.error(`Unknown product ID purchased: ${productId}`);
                    return reply.code(200).send(); // Ack to prevent RC retries
            }

            try {
                const amountDecimal = new Prisma.Decimal(wacAmount);

                // 3. Perform a Prisma Transaction to safely add WAC and log the ledger event
                await prisma.$transaction(async (tx) => {
                    // Add WAC to the user's WAC wallet (upsert in case they don't have one yet)
                    await tx.userWac.upsert({
                        where: { userId: appUserId },
                        update: {
                            wacBalance: { increment: amountDecimal },
                            balanceUpdatedAt: new Date(),
                            isActive: true,
                        },
                        create: {
                            userId: appUserId,
                            wacBalance: amountDecimal,
                            balanceUpdatedAt: new Date(),
                            isActive: true,
                        },
                    });

                    // Create ledger trail
                    await tx.transaction.create({
                        data: {
                            userId: appUserId,
                            amount: amountDecimal,
                            type: 'WAC_DEPOSIT',
                            note: `IAP purchase — product: ${productId}`,
                        }
                    });
                });

                fastify.log.info(`Securely vaulted ${wacAmount} WAC tokens for user ${appUserId}`);

            } catch (err) {
                fastify.log.error(`Failed to process RevenueCat DB transaction: ${err}`);
                return reply.code(500).send();
            }
        }

        // Always acknowledge RevenueCat events with 200 OK so it doesn't retry forever
        return reply.code(200).send({ status: 'ok' });
    });
}
