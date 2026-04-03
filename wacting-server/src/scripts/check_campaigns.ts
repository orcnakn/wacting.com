import { PrismaClient } from '@prisma/client';
const p = new PrismaClient();
const total = await p.campaign.count();
const active = await p.campaign.count({ where: { isActive: true } });
const inactive = await p.campaign.count({ where: { isActive: false } });
console.log(`Total: ${total} | Active: ${active} | Inactive: ${inactive}`);

const byStance = await p.campaign.groupBy({
  by: ['stanceType', 'isActive'],
  _count: true,
});
for (const row of byStance) {
  console.log(`  ${row.stanceType} isActive=${row.isActive}: ${row._count}`);
}
await p.$disconnect();
