/**
 * backfill_profile_levels.ts
 *
 * One-time script to calculate and cache profile levels for all existing users.
 * Run: npx tsx src/scripts/backfill_profile_levels.ts
 */

import { PrismaClient } from '@prisma/client';
import { refreshProfileLevel } from '../engine/profile_level_calculator.js';

const prisma = new PrismaClient();

async function main() {
    const users = await prisma.user.findMany({ select: { id: true } });
    console.log(`Backfilling profile levels for ${users.length} users...`);

    let count = 0;
    for (const user of users) {
        await refreshProfileLevel(prisma, user.id);
        count++;
        if (count % 100 === 0) {
            console.log(`  Processed ${count}/${users.length}`);
        }
    }

    console.log(`Done. ${count} users updated.`);
}

main()
    .catch((err) => {
        console.error('Backfill failed:', err);
        process.exit(1);
    })
    .finally(() => prisma.$disconnect());
