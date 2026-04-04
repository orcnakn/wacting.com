/**
 * backfill_campaign_levels.ts
 *
 * Recalculates and caches the level (+ physical size) for every campaign
 * in the DB based on current member count, WAC staked, and creation date.
 *
 * Run: npx tsx src/scripts/backfill_campaign_levels.ts
 */

import { PrismaClient } from '@prisma/client';
import { calculateLevel } from '../engine/level_calculator.js';

const prisma = new PrismaClient();

async function main() {
    const campaigns = await prisma.campaign.findMany({
        select: { id: true, title: true, createdAt: true, totalWacStaked: true },
    });

    console.log(`Backfilling campaign levels for ${campaigns.length} campaigns...`);

    let count = 0;
    for (const c of campaigns) {
        const memberCount = await prisma.campaignMember.count({ where: { campaignId: c.id } });
        const wac = parseFloat(c.totalWacStaked.toString());
        const lc = calculateLevel(memberCount, c.createdAt, wac);

        await prisma.campaign.update({
            where: { id: c.id },
            data: {
                cachedLevel: lc.totalLevel,
                cachedWidthMeters: lc.widthMeters,
                cachedHeightMeters: lc.heightMeters,
            },
        });

        count++;
        console.log(
            `  [${count}/${campaigns.length}] ${c.title.padEnd(35)} ` +
            `L${lc.totalLevel.toFixed(1).padStart(5)} ` +
            `(members=${memberCount}, wac=${wac}, yearLevel=${lc.yearLevel}) ` +
            `size=${lc.widthMeters.toFixed(1)}m×${lc.heightMeters.toFixed(1)}m`
        );
    }

    console.log(`\nDone. ${count} campaigns updated.`);
}

main()
    .catch(err => {
        console.error('Backfill failed:', err);
        process.exit(1);
    })
    .finally(() => prisma.$disconnect());
