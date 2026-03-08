import { Queue, Worker, Job } from 'bullmq';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK using secure Service Account JSON
// admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

// Connect BullMQ to our local Redis instance defined in docker-compose
const connection = {
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: parseInt(process.env.REDIS_PORT || '6379', 10),
};

export const notificationQueue = new Queue('geo-notifications', { connection });

// Background Worker: Pulls jobs off the Redis queue and fires them to Apple/Google
const worker = new Worker('geo-notifications', async (job: Job) => {
    const { title, body, fcmToken } = job.data;

    try {
        const message = {
            notification: { title, body },
            token: fcmToken
        };

        // Await the Firebase push request
        // const response = await admin.messaging().send(message);
        console.log(`[BullMQ Worker] Push Notification dispatched locally: ${title}`);

        return true;
    } catch (err) {
        console.error(`[BullMQ Worker] Failed to send push: ${err}`);
        throw err;
    }
}, { connection });

worker.on('failed', (job, err) => {
    console.log(`[BullMQ Worker] Job ${job?.id} failed with error ${err.message}`);
});
