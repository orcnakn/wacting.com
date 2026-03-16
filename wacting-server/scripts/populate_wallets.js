import { PrismaClient } from '@prisma/client';
import crypto from 'crypto';

const p = new PrismaClient();

function generateWalletId() {
    return crypto.randomBytes(12).toString('hex').slice(0, 24);
}

const users = await p.user.findMany({ where: { walletId: null } });
console.log('Users without walletId:', users.length);
for (const u of users) {
    await p.user.update({
        where: { id: u.id },
        data: { walletId: generateWalletId() },
    });
}
console.log('Done.');
await p.$disconnect();
