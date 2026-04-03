// @ts-nocheck
/**
 * cleanup_campaigns.ts — Keep exactly 262 active campaigns.
 *
 * If there are more than 262 active campaigns, deactivates the excess ones.
 * Members are NOT removed — campaigns can have many members.
 * The map duplicate fix is in index.ts: only the leader's icon shows
 * the campaign tabela (slogan, level, dimensions). Members show as user dots.
 *
 * Run: npx tsx src/scripts/cleanup_campaigns.ts
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const activeCampaigns = await prisma.campaign.findMany({
    where: { isActive: true },
    include: {
      _count: { select: { members: true } },
    },
    orderBy: { createdAt: 'asc' },
  });

  console.log(`\n📊 Current active campaigns: ${activeCampaigns.length}`);

  if (activeCampaigns.length > 262) {
    const toDeactivate = activeCampaigns.slice(262);
    const deactivateIds = toDeactivate.map(c => c.id);
    console.log(`\n🔻 Deactivating ${toDeactivate.length} excess campaigns...`);
    for (const c of toDeactivate) {
      console.log(`   - ${c.title} (${c.stanceType}, ${c._count.members} members)`);
    }

    const result = await prisma.campaign.updateMany({
      where: { id: { in: deactivateIds } },
      data: { isActive: false },
    });
    console.log(`   ✅ ${result.count} campaigns deactivated.`);
  } else {
    console.log(`   ✅ Already at or below 262 active campaigns.`);
  }

  // Final report
  const finalActive = await prisma.campaign.count({ where: { isActive: true } });
  const totalMembers = await (prisma as any).campaignMember.count({
    where: { campaign: { isActive: true } },
  });

  console.log(`\n📊 Final state:`);
  console.log(`   Active campaigns: ${finalActive}`);
  console.log(`   Total memberships in active campaigns: ${totalMembers}`);
  console.log(`\n✅ Done! Map tabelalar will show 1 per campaign (leader only — fixed in index.ts).`);
}

main()
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
