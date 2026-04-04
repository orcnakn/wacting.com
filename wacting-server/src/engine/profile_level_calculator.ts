/**
 * profile_level_calculator.ts
 *
 * Profile level = max(1, min(200, followerLevel + ageLevel + wacLevel))
 *
 * Follower level:  FLOOR(MAX(0, (LOG10(followers) - 1) * 10))
 * Age level:       1 + full years since profile creation
 * WAC level:       FLOOR(MAX(0, (LOG10(wacBalance) - 1) * 10))
 *
 * Distribution: ~70% of profiles land at L30 or below (logarithmic scaling
 * makes high levels exponentially rarer). Maximum is capped at 200.
 * All profiles start at minimum L1 (ageLevel ≥ 1 for new accounts).
 */

import { PrismaClient } from '@prisma/client';

export interface ProfileLevelComponents {
    followerLevel: number;
    ageLevel: number;
    wacLevel: number;
    totalLevel: number;
}

/**
 * FLOOR(MAX(0, (LOG10(value) - 1) * 10))
 * Needs at least 10 to produce any level.
 */
function flooredLogComponent(value: number): number {
    if (value < 10) return 0;
    return Math.floor((Math.log10(value) - 1) * 10);
}

/**
 * 1 + full years since creation. A brand-new profile = 1.
 */
function ageLevelSince(createdAt: Date): number {
    const now = new Date();
    let years = now.getFullYear() - createdAt.getFullYear();
    const monthDiff = now.getMonth() - createdAt.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < createdAt.getDate())) {
        years--;
    }
    return 1 + Math.max(0, years);
}

/**
 * Calculate the full profile level breakdown.
 */
export function calculateProfileLevel(
    followerCount: number,
    createdAt: Date,
    wacBalance: number,
): ProfileLevelComponents {
    const followerLevel = flooredLogComponent(followerCount);
    const ageLevel = ageLevelSince(createdAt);
    const wacLevel = flooredLogComponent(wacBalance);
    const totalLevel = Math.max(1, Math.min(200, followerLevel + ageLevel + wacLevel));
    return { followerLevel, ageLevel, wacLevel, totalLevel };
}

/**
 * Query DB inputs and update the cached profile level fields for a user.
 */
export async function refreshProfileLevel(
    prisma: PrismaClient | Parameters<Parameters<PrismaClient['$transaction']>[0]>[0],
    userId: string,
): Promise<void> {
    const db = prisma as any;

    const user = await db.user.findUnique({
        where: { id: userId },
        select: { createdAt: true },
    });
    if (!user) return;

    const followerCount = await db.follow.count({
        where: { followingId: userId, status: 'APPROVED' },
    });

    const userWac = await db.userWac.findUnique({
        where: { userId },
        select: { wacBalance: true },
    });
    const wacBalance = parseFloat(userWac?.wacBalance?.toString() ?? '0');

    const lc = calculateProfileLevel(followerCount, user.createdAt, wacBalance);

    await db.user.update({
        where: { id: userId },
        data: {
            cachedProfileLevel: lc.totalLevel,
            cachedFollowerLevel: lc.followerLevel,
            cachedAgeLevel: lc.ageLevel,
            cachedWacLevel: lc.wacLevel,
        },
    });
}
