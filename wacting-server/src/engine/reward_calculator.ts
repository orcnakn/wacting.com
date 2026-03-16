/**
 * reward_calculator.ts — Campaign-based Daily Reward System
 *
 * Formula (from tokenomics plan):
 *   dailyPool = √(totalSystemStaked) × 2
 *   campaignShare = (campaignStaked / totalSystemStaked) × dailyPool
 *
 * This replaces the old tier-based system. Rewards are proportional
 * to each campaign's WAC stake relative to the total system.
 *
 * RAC Decay formula (-1 Rule):
 *   dailyDecay = protestorCount × 1
 *   netDecay = dailyDecay - dailyRankingPoints
 *   If netDecay ≤ 0, no decay happens (life-water from ranking)
 */

export function formatWac(value: number): string {
  // Floor at 6th decimal place
  const floored = Math.floor(value * 1000000) / 1000000;
  // Format to 6 decimal places then remove trailing zeros
  let str = floored.toFixed(6);
  // Remove trailing zeros after decimal point
  str = str.replace(/\.?0+$/, '');
  return str;
}

export interface CampaignRewardInput {
    campaignId: string;
    leaderId: string;
    totalWacStaked: number;
}

export interface CampaignRewardEntry {
    campaignId: string;
    leaderId: string;
    totalWacStaked: number;
    rewardWac: number;
    sharePercent: number;
}

/**
 * Computes the daily reward pool size.
 * Formula: √(totalSystemStaked) × 2
 * This provides logarithmic growth — rewards scale with system size
 * but don't grow linearly (prevents hyperinflation).
 */
export function computeDailyPool(totalSystemStaked: number): number {
    if (totalSystemStaked <= 0) return 0;
    return Math.sqrt(totalSystemStaked) * 2;
}

/**
 * Computes rewards for all active campaigns in one pass.
 * Each campaign gets a proportional share of the daily pool.
 *
 * @param campaigns - Active campaigns with WAC staked
 * @param circulatingSupply - Current total WAC in circulation
 * @param maxSupply - Maximum WAC supply guard (default: Infinity for unlimited supply)
 */
export function computeAllCampaignRewards(
    campaigns: CampaignRewardInput[],
    circulatingSupply = 0,
    maxSupply = Infinity
): CampaignRewardEntry[] {
    if (campaigns.length === 0) return [];

    const totalSystemStaked = campaigns.reduce((s, c) => s + c.totalWacStaked, 0);
    if (totalSystemStaked <= 0) return campaigns.map((c) => ({
        ...c,
        rewardWac: 0,
        sharePercent: 0,
    }));

    const dailyPool = computeDailyPool(totalSystemStaked);
    let runningSupply = circulatingSupply;

    return campaigns.map((c) => {
        const sharePercent = c.totalWacStaked / totalSystemStaked;
        const reward = Math.round(sharePercent * dailyPool * 1_000_000) / 1_000_000;

        // Max supply guard
        const clampedReward = Math.min(reward, maxSupply - runningSupply);
        if (clampedReward <= 0) {
            return { ...c, rewardWac: 0, sharePercent };
        }

        runningSupply += clampedReward;
        return {
            ...c,
            rewardWac: clampedReward,
            sharePercent,
        };
    });
}

// ─── RAC Decay ───────────────────────────────────────────────────────────────

export interface RacDecayInput {
    campaignId: string;
    poolId: string;
    totalRacBalance: bigint;
    protestorCount: number;
    dailyRankingPoints: number;
}

export interface RacDecayResult {
    poolId: string;
    campaignId: string;
    decayAmount: bigint;
    bonusAmount: bigint;
    netDecay: bigint;
    newBalance: bigint;
    shouldDeactivate: boolean;
}

/**
 * Computes RAC decay for a protest pool.
 *
 * -1 Rule: Each protestor causes 1 RAC/day to decay.
 * Life-Water: Daily ranking points offset the decay.
 *
 * Net decay = (protestorCount × 1) - floor(dailyRankingPoints)
 * If net ≤ 0, no decay (the campaign's ranking bonus saves the pool).
 */
export function computeRacDecay(input: RacDecayInput): RacDecayResult {
    const decayAmount = BigInt(input.protestorCount); // -1 per protestor
    const bonusAmount = BigInt(Math.floor(input.dailyRankingPoints)); // ranking points as RAC bonus

    const netDecayRaw = decayAmount - bonusAmount;
    const netDecay = netDecayRaw > 0n ? netDecayRaw : 0n;

    // Can't decay more than what's in the pool
    const actualDecay = netDecay > input.totalRacBalance ? input.totalRacBalance : netDecay;
    const newBalance = input.totalRacBalance - actualDecay;

    return {
        poolId: input.poolId,
        campaignId: input.campaignId,
        decayAmount,
        bonusAmount,
        netDecay: actualDecay,
        newBalance,
        shouldDeactivate: newBalance <= 0n,
    };
}

// ─── Legacy exports (backward compat for existing tests) ─────────────────────

export const BASE_REWARD = 1;

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

export function getTierBonus(usersBelow: number): number {
    for (const tier of TIERS) {
        if (usersBelow >= tier.minUsersBelow) return tier.bonus;
    }
    return 0;
}

export function computeDailyReward(usersBelow: number): number {
    return Math.round((BASE_REWARD + getTierBonus(usersBelow)) * 1_000_000) / 1_000_000;
}
