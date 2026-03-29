/**
 * level_calculator.ts
 *
 * Campaign level = followerLevel + yearsActive + wacLevel
 *
 * Follower level:  IF(LOG10(members) - 1 >= 0, (LOG10(members) - 1) * 10, 0)
 * Year level:      years since campaign creation (integer)
 * WAC level:       IF(LOG10(totalWacStaked) - 1 >= 0, (LOG10(totalWacStaked) - 1) * 10, 0)
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
 * width = baseValue * 2, height = baseValue
 */
export function levelToPhysicalSize(level: number): { widthMeters: number; heightMeters: number } {
    if (level <= 0) return { widthMeters: 0, heightMeters: 0 };
    const baseValue = Math.pow(level, 2) * Math.sqrt(level);
    return { widthMeters: baseValue * 2, heightMeters: baseValue };
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
    const totalLevel = followerLevel + yearLevel + wacLevel;
    const { widthMeters, heightMeters } = levelToPhysicalSize(totalLevel);

    return { followerLevel, yearLevel, wacLevel, totalLevel, widthMeters, heightMeters };
}
