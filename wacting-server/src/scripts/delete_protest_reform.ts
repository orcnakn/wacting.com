/**
 * Deactivate all PROTEST and REFORM campaigns (set isActive = false).
 * Safe approach — no data loss, no FK risks. UI already filters by isActive.
 * Run: npx tsx src/scripts/delete_protest_reform.ts
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // Find all active PROTEST and REFORM campaigns
  const campaigns = await prisma.campaign.findMany({
    where: {
      stanceType: { in: ['PROTEST', 'REFORM'] },
      isActive: true,
    },
    select: { id: true, title: true, stanceType: true },
  });

  console.log(`Found ${campaigns.length} active PROTEST/REFORM campaigns:`);
  for (const c of campaigns) {
    console.log(`  - [${c.stanceType}] ${c.title} (${c.id})`);
  }

  if (campaigns.length === 0) {
    console.log('Nothing to deactivate.');
    return;
  }

  // Deactivate all at once
  const result = await prisma.campaign.updateMany({
    where: {
      stanceType: { in: ['PROTEST', 'REFORM'] },
      isActive: true,
    },
    data: { isActive: false },
  });

  console.log(`\n✅ ${result.count} PROTEST/REFORM campaigns deactivated.`);
}

main()
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
