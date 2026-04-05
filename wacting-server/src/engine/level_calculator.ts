/**
 * level_calculator.ts
 *
 * Campaign level = max(1, min(200, followerLevel + yearsActive + wacLevel))
 *
 * Follower level:  IF(LOG10(members) - 1 >= 0, (LOG10(members) - 1) * 10, 0)
 * Year level:      years since campaign creation (integer)
 * WAC level:       IF(LOG10(totalWacStaked) - 1 >= 0, (LOG10(totalWacStaked) - 1) * 10, 0)
 *
 * Distribution: ~70% of campaigns land at L30 or below (logarithmic scaling
 * makes high levels exponentially rarer). Maximum is capped at 200.
 *
 * Physical sign size (meters):
 *   baseValue = level^2 * sqrt(level)
 *   width     = baseValue * 2     (2:1 aspect ratio)
 *   height    = baseValue
 */

export interface LevelComponents {
    followerLevel: number;
    yearLevel: number;
    wacLevel: number;
    totalLevel: number;
    widthMeters: number;
    heightMeters: number;
}

/**
 * Logarithmic component: IF(LOG10(value) - 1 >= 0, (LOG10(value) - 1) * 10, 0)
 * Needs at least 10 to produce any level (log10(10) - 1 = 0).
 */
function logComponent(value: number): number {
    if (value < 10) return 0;
    return (Math.log10(value) - 1) * 10;
}

/**
 * Compute full years since a given date.
 */
function yearsSince(date: Date): number {
    const now = new Date();
    let years = now.getFullYear() - date.getFullYear();
    const monthDiff = now.getMonth() - date.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < date.getDate())) {
        years--;
    }
    return Math.max(0, years);
}

/**
 * Convert a level to physical sign dimensions in meters.
 * baseValue = level^2 * sqrt(level)
 * width = baseValue * MAP_SCALE, height = width / 2
 *
 * MAP_SCALE = 100 makes level-based sizes practical for map rendering:
 *   L1  →   100m  (polygon at zoom ≈10)
 *   L5  →  5,590m (polygon at zoom ≈7)
 *   L10 → 31,623m (polygon at zoom ≈5)
 *   L20 → 178,885m (polygon at zoom ≈3)
 *
 * Minimum 50,000m ensures even L1 campaigns appear as dots from zoom ≈4.
 */
export function levelToPhysicalSize(level: number): { widthMeters: number; heightMeters: number } {
    if (level <= 0) return { widthMeters: 0, heightMeters: 0 };
    const baseValue = Math.pow(level, 2) * Math.sqrt(level);
    const widthMeters = Math.max(50000, baseValue * 100);
    const heightMeters = widthMeters / 2;
    return { widthMeters, heightMeters };
}

/**
 * Calculate the full level breakdown for a campaign.
 */
export function calculateLevel(
    memberCount: number,
    createdAt: Date,
    totalWacStaked: number,
): LevelComponents {
    const followerLevel = logComponent(memberCount);
    const yearLevel = yearsSince(createdAt);
    const wacLevel = logComponent(totalWacStaked);
    const totalLevel = Math.max(1, Math.min(200, followerLevel + yearLevel + wacLevel));
    const { widthMeters, heightMeters } = levelToPhysicalSize(totalLevel);

    return { followerLevel, yearLevel, wacLevel, totalLevel, widthMeters, heightMeters };
}
