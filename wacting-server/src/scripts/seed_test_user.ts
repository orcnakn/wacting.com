import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  // Check if already exists
  const existing = await prisma.user.findUnique({ where: { email: 'test@wacting.com' } });
  if (existing) {
    console.log('Test user already exists, ID:', existing.id);
    await prisma.$disconnect();
    return;
  }

  const hash = await bcrypt.hash('test123', 10);

  const user = await prisma.user.create({
    data: {
      email: 'test@wacting.com',
      passwordHash: hash,
      emailVerified: true,
      displayName: 'Test User',
      slogan: 'Test Commander',
      status: 'ACTIVE',
      role: 'ADMIN',
    }
  });

  await prisma.userWac.create({
    data: { userId: user.id, wacBalance: 1000, isActive: true }
  });

  await prisma.icon.create({
    data: {
      userId: user.id,
      slogan: 'Test Commander',
      colorHex: '#1ABC9C',
      shapeIndex: 0,
      locationEnabled: true,
      locationLat: 41.0082,
      locationLng: 28.9784,
    }
  });

  console.log('Test user created!');
  console.log('  Email: test@wacting.com');
  console.log('  Password: test123');
  console.log('  ID:', user.id);
  console.log('  Role: ADMIN');

  await prisma.$disconnect();
}
main().catch(e => { console.error(e); process.exit(1); });
