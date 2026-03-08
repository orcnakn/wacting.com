/**
 * reward_calculator.ts
 * Pure functions for computing daily WAC rewards based on tier (N = usersBelow).
 *
 * Tier table:
 *   N = 0–99           → bonus 0     → total 1 WAC
 *   N = 100–999        → bonus 0.5   → total 1.5 WAC
 *   N = 1,000–9,999    → bonus 2     → total 3 WAC
 *   N = 10,000–99,999  → bonus 5     → total 6 WAC
 *   N = 100k–999,999   → bonus 15    → total 16 WAC
 *   N ≥ 1,000,000      → bonus 40    → total 41 WAC
 *
 * Rewards are returned as numbers with 6-decimal precision.
 * MAX_SUPPLY guard is enforced at the snapshot level, not here.
 */

export const BASE_REWARD = 1;  // WAC — every active participant earns this

export interface TierConfig {
    minUsersBelow: number;
    bonus: number;
}

export const TIERS: TierConfig[] = [
    { minUsersBelow: 1_000_000, bonus: 40 },
    { minUsersBelow: 100_000, bonus: 15 },
    { minUsersBelow: 10_000, bonus: 5 },
    { minUsersBelow: 1_000, bonus: 2 },
    { minUsersBelow: 100, bonus: 0.5 },
    { minUsersBelow: 0, bonus: 0 },
];

/**
 * Returns the tier bonus (not total) for a given usersBelow count.
 */
export function getTierBonus(usersBelow: number): number {
    for (const tier of TIERS) {
        if (usersBelow >= tier.minUsersBelow) {
            return tier.bonus;
        }
    }
    return 0;
}

/**
 * Returns the total daily WAC reward (base + tier bonus) rounded to 6 dp.
 */
export function computeDailyReward(usersBelow: number): number {
    const reward = BASE_REWARD + getTierBonus(usersBelow);
    return Math.round(reward * 1_000_000) / 1_000_000;
}

export interface RewardEntry {
    userId: string;
    rank: number;
    usersBelow: number;
    rewardWac: number;
}

/**
 * Computes rewards for an entire ranked snapshot in one pass.
 *
 * @param rankedUsers - Already ranked list (rank, usersBelow populated)
 * @param circulatingSupply - Current total WAC minted (to enforce max supply)
 * @param maxSupply - Default 85,016,666,666,667 WAC
 */
export function computeAllRewards(
    rankedUsers: Array<{ userId: string; rank: number; usersBelow: number }>,
    circulatingSupply: number,
    maxSupply = 85_016_666_666_667
): RewardEntry[] {
    const entries: RewardEntry[] = [];
    let runningSupply = circulatingSupply;

    for (const user of rankedUsers) {
        const reward = computeDailyReward(user.usersBelow);
        const clampedReward = Math.min(reward, maxSupply - runningSupply);

        if (clampedReward <= 0) {
            entries.push({ ...user, rewardWac: 0 });
            continue;
        }

        runningSupply += clampedReward;
        entries.push({ ...user, rewardWac: Math.round(clampedReward * 1_000_000) / 1_000_000 });
    }

    return entries;
}
