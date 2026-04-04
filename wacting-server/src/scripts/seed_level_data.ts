/**
 * seed_level_data.ts
 *
 * Fills the DB with realistic WAC balances, follower relationships,
 * and campaigns so that the level formula produces meaningful, varied levels.
 *
 * Profile level  = max(1, min(200, followerLevel + ageLevel + wacLevel))
 *   followerLevel = FLOOR(MAX(0, (LOG10(followers) - 1) * 10))
 *   ageLevel      = 1 + full years since creation
 *   wacLevel      = FLOOR(MAX(0, (LOG10(wacBalance) - 1) * 10))
 *
 * Campaign level = max(1, min(200, followerLevel + yearLevel + wacLevel))
 *   followerLevel = (LOG10(members) - 1) * 10   (needs ≥10 members)
 *   yearLevel     = full years since campaign creation
 *   wacLevel      = (LOG10(totalWacStaked) - 1) * 10  (needs ≥10 WAC)
 *
 * Run: npx tsx src/scripts/seed_level_data.ts
 */

import { PrismaClient } from '@prisma/client';
import { refreshProfileLevel } from '../engine/profile_level_calculator.js';
import { calculateLevel } from '../engine/level_calculator.js';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

// ---------------------------------------------------------------------------
// Level tiers we want to demonstrate
// ---------------------------------------------------------------------------
// WAC amounts that produce specific wacLevels:
//   wacLevel = FLOOR((LOG10(wac) - 1) * 10)
//   wac ≈ 10^(1 + level/10)
//   L0  → <10 WAC
//   L5  → ~31 WAC
//   L10 → 100 WAC
//   L15 → ~316 WAC
//   L20 → 1 000 WAC
//   L25 → ~3 162 WAC
//   L30 → 10 000 WAC
//   L40 → 100 000 WAC

interface BotProfile {
    displayName: string;
    slogan: string;
    wac: number;          // WAC balance → drives wacLevel
    followersToCreate: number; // how many bots will follow this user
    lat: number;
    lng: number;
    createdYearsAgo: number;  // simulates account age (ageLevel = 1 + years)
}

const BOT_PROFILES: BotProfile[] = [
    // Low tier L1-L5
    { displayName: 'Mia Demir',     slogan: 'Değişim için buradayım',  wac: 5,       followersToCreate: 3,     lat: 41.015, lng: 28.979, createdYearsAgo: 0 },
    { displayName: 'Can Yıldız',    slogan: 'Güçlü ses',               wac: 8,       followersToCreate: 5,     lat: 39.920, lng: 32.854, createdYearsAgo: 0 },

    // Mid tier L6-L15  (wac 100-500, followers 10-100)
    { displayName: 'Ayşe Kara',     slogan: 'Toplum için söz',         wac: 120,     followersToCreate: 25,    lat: 38.420, lng: 27.128, createdYearsAgo: 1 },
    { displayName: 'Emre Çelik',    slogan: 'Birlikte ileri',          wac: 250,     followersToCreate: 50,    lat: 37.000, lng: 35.321, createdYearsAgo: 1 },
    { displayName: 'Selin Arslan',  slogan: 'Haklarımız için',         wac: 400,     followersToCreate: 80,    lat: 40.190, lng: 29.061, createdYearsAgo: 2 },

    // High tier L16-L30  (wac 1k-10k, followers 100-1000)
    { displayName: 'Tarık Öztürk',  slogan: 'Lider sesini duyur',      wac: 1500,    followersToCreate: 200,   lat: 41.680, lng: 26.558, createdYearsAgo: 2 },
    { displayName: 'Naz Şahin',     slogan: 'Güçlü kampanya',          wac: 3000,    followersToCreate: 400,   lat: 36.885, lng: 30.705, createdYearsAgo: 3 },
    { displayName: 'Burak Koç',     slogan: 'Binlerce destekçi',       wac: 8000,    followersToCreate: 800,   lat: 40.900, lng: 29.380, createdYearsAgo: 3 },

    // Elite tier L31-L50  (wac 10k+, followers 1000+)
    { displayName: 'Leyla Avcı',    slogan: 'Ulusal hareket',          wac: 12000,   followersToCreate: 1200,  lat: 38.730, lng: 35.489, createdYearsAgo: 4 },
    { displayName: 'Murat Erdoğan', slogan: 'On binlerin sesi',        wac: 50000,   followersToCreate: 3000,  lat: 37.870, lng: 32.480, createdYearsAgo: 5 },
];

// ---------------------------------------------------------------------------
// Campaign seeds — varied member counts and WAC staked
// ---------------------------------------------------------------------------
interface CampaignSeed {
    title: string;
    slogan: string;
    description: string;
    iconColor: string;
    iconShape: number;
    lat: number;
    lng: number;
    stanceType: 'SUPPORT' | 'EMERGENCY';
    categoryType: 'GLOBAL_PEACE' | 'JUSTICE_RIGHTS' | 'ECOLOGY_NATURE' | 'TECH_FUTURE' | 'SOLIDARITY_RELIEF' | 'ECONOMY_LABOR' | 'AWARENESS' | 'ENTERTAINMENT';
    memberCount: number;  // drives followerLevel
    totalWacStaked: number; // drives wacLevel
    createdYearsAgo: number; // drives yearLevel
}

const CAMPAIGN_SEEDS: CampaignSeed[] = [
    // L1-L5: tiny campaigns
    {
        title: 'Temiz Su Hakkı',
        slogan: 'Herkes için temiz su',
        description: 'Kırsal bölgelerdeki içme suyu erişim sorunlarına dikkat çekiyoruz.',
        iconColor: '#2196F3', iconShape: 0,
        lat: 39.92, lng: 32.85,
        stanceType: 'SUPPORT', categoryType: 'SOLIDARITY_RELIEF',
        memberCount: 4, totalWacStaked: 8, createdYearsAgo: 0,
    },
    {
        title: 'Gürültü Kirliliği',
        slogan: 'Sessiz şehirler istiyoruz',
        description: 'Kentsel gürültü kirliliğini azaltmak için farkındalık.',
        iconColor: '#FF5722', iconShape: 1,
        lat: 41.02, lng: 28.97,
        stanceType: 'SUPPORT', categoryType: 'AWARENESS',
        memberCount: 7, totalWacStaked: 12, createdYearsAgo: 0,
    },

    // L6-L15: küçük-orta kampanyalar
    {
        title: 'Yeşil Ulaşım',
        slogan: 'Bisiklet yolları şehrimizde',
        description: 'Sürdürülebilir ulaşım için bisiklet altyapısı talep ediyoruz.',
        iconColor: '#4CAF50', iconShape: 2,
        lat: 38.42, lng: 27.13,
        stanceType: 'SUPPORT', categoryType: 'ECOLOGY_NATURE',
        memberCount: 30, totalWacStaked: 150, createdYearsAgo: 1,
    },
    {
        title: 'Ücretsiz Eğitim',
        slogan: 'Herkes için kaliteli eğitim',
        description: 'Yükseköğretimde fırsat eşitliği için kampanya.',
        iconColor: '#9C27B0', iconShape: 0,
        lat: 37.00, lng: 35.32,
        stanceType: 'SUPPORT', categoryType: 'JUSTICE_RIGHTS',
        memberCount: 80, totalWacStaked: 400, createdYearsAgo: 1,
    },
    {
        title: 'İfade Özgürlüğü',
        slogan: 'Söz hakkımızı kullanıyoruz',
        description: 'Basın özgürlüğü ve ifade hürriyeti için dayanışma.',
        iconColor: '#FF9800', iconShape: 3,
        lat: 40.19, lng: 29.06,
        stanceType: 'SUPPORT', categoryType: 'JUSTICE_RIGHTS',
        memberCount: 120, totalWacStaked: 600, createdYearsAgo: 2,
    },

    // L16-L30: orta-büyük kampanyalar
    {
        title: 'Ormansızlaşmaya Hayır',
        slogan: 'Ağaçlarımızı koruyun',
        description: 'Türkiye\'deki orman tahribatını durdurmak için kitlesel hareket.',
        iconColor: '#388E3C', iconShape: 1,
        lat: 41.68, lng: 26.56,
        stanceType: 'SUPPORT', categoryType: 'ECOLOGY_NATURE',
        memberCount: 350, totalWacStaked: 2500, createdYearsAgo: 2,
    },
    {
        title: 'Dijital Haklar',
        slogan: 'İnternet sansürüne son',
        description: 'Açık internet ve dijital özgürlükler için güçlü destek.',
        iconColor: '#1976D2', iconShape: 2,
        lat: 36.89, lng: 30.71,
        stanceType: 'SUPPORT', categoryType: 'TECH_FUTURE',
        memberCount: 600, totalWacStaked: 5000, createdYearsAgo: 3,
    },
    {
        title: 'Asgari Ücret Adaleti',
        slogan: 'Geçim sağlayan ücret hakkımız',
        description: 'Yaşam maliyetiyle orantılı asgari ücret talebi.',
        iconColor: '#F44336', iconShape: 0,
        lat: 40.90, lng: 29.38,
        stanceType: 'SUPPORT', categoryType: 'ECONOMY_LABOR',
        memberCount: 900, totalWacStaked: 7500, createdYearsAgo: 3,
    },

    // L31-L50: büyük/elit kampanyalar
    {
        title: 'İklim Acil Durumu',
        slogan: 'Gezegenimiz yanıyor',
        description: 'İklim değişikliğiyle mücadele için acil eylem çağrısı.',
        iconColor: '#FF6F00', iconShape: 3,
        lat: 38.73, lng: 35.49,
        stanceType: 'EMERGENCY', categoryType: 'ECOLOGY_NATURE',
        memberCount: 1500, totalWacStaked: 15000, createdYearsAgo: 4,
    },
    {
        title: 'Halk Sağlığı Acil',
        slogan: 'Sağlık hizmetleri kriz noktasında',
        description: 'Bozulan kamu sağlığı altyapısı için acil kaynak talebi.',
        iconColor: '#D32F2F', iconShape: 1,
        lat: 37.87, lng: 32.48,
        stanceType: 'EMERGENCY', categoryType: 'SOLIDARITY_RELIEF',
        memberCount: 4000, totalWacStaked: 45000, createdYearsAgo: 5,
    },
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function yearsAgoDate(years: number): Date {
    const d = new Date();
    d.setFullYear(d.getFullYear() - years);
    // Subtract a few days so "full years" math works correctly
    d.setDate(d.getDate() - 5);
    return d;
}

function flooredLogComponent(value: number): number {
    if (value < 10) return 0;
    return Math.floor((Math.log10(value) - 1) * 10);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
    console.log('=== seed_level_data.ts ===\n');

    // ── 1. Fix existing Test User WAC cache ──────────────────────────────────
    const testUser = await prisma.user.findUnique({ where: { email: 'test@wacting.com' } });
    if (testUser) {
        await refreshProfileLevel(prisma, testUser.id);
        const updated = await prisma.user.findUnique({
            where: { id: testUser.id },
            select: { cachedProfileLevel: true, cachedWacLevel: true },
        });
        console.log(`Test User level refreshed → L${updated?.cachedProfileLevel} (wacLevel=${updated?.cachedWacLevel})`);
    }

    // ── 2. Create bot users with varied WAC + follow relationships ────────────
    const botIds: string[] = [];
    const hash = await bcrypt.hash('bot_unused_pw', 10);

    for (let i = 0; i < BOT_PROFILES.length; i++) {
        const bp = BOT_PROFILES[i];
        const email = `bot_level_${i}@wacting.com`;

        let bot = await prisma.user.findUnique({ where: { email } });
        if (!bot) {
            const createdAt = yearsAgoDate(bp.createdYearsAgo);
            bot = await prisma.user.create({
                data: {
                    email,
                    passwordHash: hash,
                    emailVerified: true,
                    displayName: bp.displayName,
                    slogan: bp.slogan,
                    status: 'ACTIVE',
                    role: 'USER',
                    isBot: true,
                    createdAt,
                },
            });

            // WAC balance
            await prisma.userWac.create({
                data: { userId: bot.id, wacBalance: bp.wac, isActive: true },
            });

            // Map icon
            await prisma.icon.create({
                data: {
                    userId: bot.id,
                    slogan: bp.slogan,
                    colorHex: '#' + Math.floor(Math.random() * 0xffffff).toString(16).padStart(6, '0'),
                    shapeIndex: i % 4,
                    locationEnabled: true,
                    locationLat: bp.lat + (Math.random() - 0.5) * 0.5,
                    locationLng: bp.lng + (Math.random() - 0.5) * 0.5,
                },
            });

            console.log(`  Created bot: ${bp.displayName} (${bp.wac} WAC, ${bp.createdYearsAgo}yr old)`);
        }
        botIds.push(bot.id);
    }

    // ── 3. Create follow relationships to build follower counts ──────────────
    // Each bot "followersToCreate" bots follow it (using other bots as followers).
    // We create follows from earlier bots towards later higher-tier bots.
    console.log('\nCreating follow relationships...');
    let followsCreated = 0;

    for (let targetIdx = 0; targetIdx < BOT_PROFILES.length; targetIdx++) {
        const bp = BOT_PROFILES[targetIdx];
        const targetId = botIds[targetIdx];
        const needed = bp.followersToCreate;

        // Distribute followers: loop through all other bots + test user
        const allUserIds = testUser ? [testUser.id, ...botIds] : [...botIds];
        const followers = allUserIds.filter(id => id !== targetId);

        // If we need more followers than available users, we'll use what we have
        const toFollow = Math.min(needed, followers.length);

        for (let j = 0; j < toFollow; j++) {
            const followerId = followers[j % followers.length];
            if (followerId === targetId) continue;

            try {
                await prisma.follow.upsert({
                    where: { followerId_followingId: { followerId, followingId: targetId } },
                    create: { followerId, followingId: targetId, status: 'APPROVED' },
                    update: { status: 'APPROVED' },
                });
                followsCreated++;
            } catch {
                // duplicate — skip
            }
        }
    }
    console.log(`  ${followsCreated} follow records created/updated`);

    // ── 4. Refresh all profile level caches ──────────────────────────────────
    console.log('\nRefreshing profile level caches...');
    const allUsers = await prisma.user.findMany({ select: { id: true, displayName: true } });
    for (const u of allUsers) {
        await refreshProfileLevel(prisma, u.id);
    }
    // Print results
    const levels = await prisma.user.findMany({
        select: {
            displayName: true,
            cachedProfileLevel: true,
            cachedFollowerLevel: true,
            cachedAgeLevel: true,
            cachedWacLevel: true,
        },
        orderBy: { cachedProfileLevel: 'desc' },
    });
    console.log('\nProfile levels after seed:');
    levels.forEach(u =>
        console.log(`  ${u.displayName.padEnd(20)} L${u.cachedProfileLevel} (follow=${u.cachedFollowerLevel} age=${u.cachedAgeLevel} wac=${u.cachedWacLevel})`)
    );

    // ── 5. Create campaigns ───────────────────────────────────────────────────
    console.log('\nCreating campaigns...');

    // Pick a leader for each campaign (round-robin across bots, start at higher-tier)
    const leaderPool = [...botIds].reverse(); // elite bots first
    if (testUser) leaderPool.push(testUser.id);

    for (let ci = 0; ci < CAMPAIGN_SEEDS.length; ci++) {
        const cs = CAMPAIGN_SEEDS[ci];
        const leaderId = leaderPool[ci % leaderPool.length];

        // Check if campaign with same title already exists
        const existing = await prisma.campaign.findFirst({ where: { title: cs.title } });
        if (existing) {
            console.log(`  Skipped (exists): ${cs.title}`);
            continue;
        }

        const createdAt = yearsAgoDate(cs.createdYearsAgo);

        const campaign = await prisma.campaign.create({
            data: {
                leaderId,
                title: cs.title,
                slogan: cs.slogan,
                description: cs.description,
                iconColor: cs.iconColor,
                iconShape: cs.iconShape,
                pinnedLat: cs.lat + (Math.random() - 0.5) * 0.2,
                pinnedLng: cs.lng + (Math.random() - 0.5) * 0.2,
                stanceType: cs.stanceType,
                categoryType: cs.categoryType,
                isActive: true,
                totalWacStaked: cs.totalWacStaked,
                createdAt,
            },
        });

        // Add leader as first member
        await prisma.campaignMember.create({
            data: {
                campaignId: campaign.id,
                userId: leaderId,
                stakedWac: cs.totalWacStaked * 0.3, // leader holds 30%
            },
        });

        // Add remaining bot members (distribute remaining WAC evenly)
        const memberPool = [...botIds, ...(testUser ? [testUser.id] : [])].filter(id => id !== leaderId);
        const remainingMembers = cs.memberCount - 1; // -1 for leader
        const membersToAdd = Math.min(remainingMembers, memberPool.length);
        const wacPerMember = membersToAdd > 0 ? (cs.totalWacStaked * 0.7) / membersToAdd : 0;

        for (let mi = 0; mi < membersToAdd; mi++) {
            const memberId = memberPool[mi % memberPool.length];
            if (memberId === leaderId) continue;
            try {
                await prisma.campaignMember.create({
                    data: {
                        campaignId: campaign.id,
                        userId: memberId,
                        stakedWac: wacPerMember,
                    },
                });
            } catch {
                // duplicate — skip
            }
        }

        // Calculate and cache the campaign level
        const actualMemberCount = await prisma.campaignMember.count({ where: { campaignId: campaign.id } });
        const lc = calculateLevel(actualMemberCount, createdAt, cs.totalWacStaked);
        await prisma.campaign.update({
            where: { id: campaign.id },
            data: {
                cachedLevel: lc.totalLevel,
                cachedWidthMeters: lc.widthMeters,
                cachedHeightMeters: lc.heightMeters,
            },
        });

        console.log(
            `  ${cs.title.padEnd(30)} L${lc.totalLevel.toFixed(1).padStart(5)} ` +
            `(members=${actualMemberCount} wac=${cs.totalWacStaked} year=${lc.yearLevel}) ` +
            `[${lc.widthMeters.toFixed(1)}m × ${lc.heightMeters.toFixed(1)}m]`
        );
    }

    // ── 6. Also recalculate any pre-existing campaigns ────────────────────────
    const allCampaigns = await prisma.campaign.findMany({
        select: { id: true, createdAt: true, totalWacStaked: true },
    });
    for (const c of allCampaigns) {
        const mc = await prisma.campaignMember.count({ where: { campaignId: c.id } });
        const wac = parseFloat(c.totalWacStaked.toString());
        const lc = calculateLevel(mc, c.createdAt, wac);
        await prisma.campaign.update({
            where: { id: c.id },
            data: {
                cachedLevel: lc.totalLevel,
                cachedWidthMeters: lc.widthMeters,
                cachedHeightMeters: lc.heightMeters,
            },
        });
    }

    console.log('\n=== Done ===');
}

main()
    .catch(err => {
        console.error('Seed failed:', err);
        process.exit(1);
    })
    .finally(() => prisma.$disconnect());
