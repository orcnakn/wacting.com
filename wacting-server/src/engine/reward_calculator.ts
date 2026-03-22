/**
 * reward_calculator.ts — Tier-Based Member Reward System
 *
 * Each member's reward is determined by their RANK within the campaign.
 * Rank = sorted by effectiveWac (stakedWac × multiplier) descending.
 *
 * Reward tiers unlock as campaign membership grows:
 *
 *   Members  | Top 100 | 101-1K | 1K-10K | 10K-100K | 100K-1M
 *   ---------|---------|--------|--------|----------|--------
 *   100      | 1 WAC   |   —    |   —    |    —     |   —
 *   1K       | 3 WAC   | 1 WAC  |   —    |    —     |   —
 *   10K      | 15 WAC  | 3 WAC  | 1 WAC  |    —     |   —
 *   100K     | 40 WAC  | 15 WAC | 3 WAC  | 1 WAC    |   —
 *   1M       | 100 WAC | 40 WAC | 15 WAC | 3 WAC    | 1 WAC
 *
 * SUPPORT:  Full WAC reward. Hype multiplier 10x (decays -1/day, min 1.0)
 * REFORM:   WAC reward × time multiplier (0.5x→10x over 180 days)
 * PROTEST:  Full WAC reward (RAC temporarily disabled)
 * EMERGENCY: No rewards (excluded from snapshot)
 *
 * REFORM time multiplier tiers:
 *   0-14 days:  0.5x
 *   14-30 days: 1.0x
 *   30-90 days: 3.0x
 *   90-180 days: 5.0x
 *   180+ days:  10.0x
 *
 */

export function formatWac(value: number): string {
    const floored = Math.floor(value * 1000000) / 1000000;
    let str = floored.toFixed(6);
    str = str.replace(/\.?0+$/, '');
    return str;
}

// ─── Tier Reward Table ──────────────────────────────────────────────────────

/** Reward tiers: [maxRank, rewardWac] pairs for each campaign size bracket */
interface RewardBracket {
    minMembers: number;
    tiers: { maxRank: number; reward: number }[];
}

const REWARD_TABLE: RewardBracket[] = [
    {
        minMembers: 1_000_000,
        tiers: [
            { maxRank: 100, reward: 100 },
            { maxRank: 1_000, reward: 40 },
            { maxRank: 10_000, reward: 15 },
            { maxRank: 100_000, reward: 3 },
            { maxRank: 1_000_000, reward: 1 },
        ],
    },
    {
        minMembers: 100_000,
        tiers: [
            { maxRank: 100, reward: 40 },
            { maxRank: 1_000, reward: 15 },
            { maxRank: 10_000, reward: 3 },
            { maxRank: 100_000, reward: 1 },
        ],
    },
    {
        minMembers: 10_000,
        tiers: [
            { maxRank: 100, reward: 15 },
            { maxRank: 1_000, reward: 3 },
            { maxRank: 10_000, reward: 1 },
        ],
    },
    {
        minMembers: 1_000,
        tiers: [
            { maxRank: 100, reward: 3 },
            { maxRank: 1_000, reward: 1 },
        ],
    },
    {
        minMembers: 1, // any campaign with at least 1 member
        tiers: [
            { maxRank: 100, reward: 1 },
        ],
    },
];

/**
 * Get the base WAC reward for a member at a given rank within a campaign of a given size.
 */
export function getMemberReward(memberCount: number, rank: number): number {
    for (const bracket of REWARD_TABLE) {
        if (memberCount >= bracket.minMembers) {
            for (const tier of bracket.tiers) {
                if (rank <= tier.maxRank) {
                    return tier.reward;
                }
            }
            return 0; // rank exceeds all tiers
        }
    }
    return 0;
}

// ─── REFORM Time Multiplier ─────────────────────────────────────────────────

export interface ReformTier {
    minDays: number;
    multiplier: number;
}

export const REFORM_TIERS: ReformTier[] = [
    { minDays: 180, multiplier: 10.0 },
    { minDays: 90, multiplier: 5.0 },
    { minDays: 30, multiplier: 3.0 },
    { minDays: 14, multiplier: 1.0 },
    { minDays: 0, multiplier: 0.5 },
];

/**
 * Get the REFORM time-based multiplier based on days since joining.
 */
export function getReformMultiplier(daysSinceJoin: number): number {
    for (const tier of REFORM_TIERS) {
        if (daysSinceJoin >= tier.minDays) return tier.multiplier;
    }
    return 0.5;
}

// ─── Member Reward Computation ──────────────────────────────────────────────

export interface MemberRewardInput {
    userId: string;
    campaignId: string;
    stakedWac: number;
    multiplier: number;
    stanceType: 'SUPPORT' | 'REFORM' | 'PROTEST' | 'EMERGENCY';
    daysSinceJoin: number;
}

export interface MemberRewardResult {
    userId: string;
    campaignId: string;
    effectiveWac: number;
    rank: number;
    wacReward: number;
    newMultiplier: number;
}

/**
 * Compute rewards for all members within a single campaign.
 *
 * 1. Sort members by effectiveWac (stakedWac × multiplier) descending
 * 2. Assign rank (1-based)
 * 3. Get base reward from tier table
 * 4. Apply stance-specific modifiers:
 *    - SUPPORT: full WAC
 *    - REFORM:  WAC × reform time multiplier
 *    - PROTEST: full WAC (RAC temporarily disabled)
 * 5. Compute new multiplier for next day
 */
export function computeCampaignMemberRewards(
    members: MemberRewardInput[],
): MemberRewardResult[] {
    if (members.length === 0) return [];

    // Calculate effective WAC and sort descending
    const sorted = members
        .map((m) => ({
            ...m,
            effectiveWac: m.stakedWac * m.multiplier,
        }))
        .sort((a, b) => {
            if (b.effectiveWac !== a.effectiveWac) return b.effectiveWac - a.effectiveWac;
            return 0; // tie-break handled by joinedAt in DB query
        });

    const memberCount = sorted.length;

    return sorted.map((m, i) => {
        const rank = i + 1;
        const baseReward = getMemberReward(memberCount, rank);

        let wacReward = 0;
        let newMultiplier = m.multiplier;

        switch (m.stanceType) {
            case 'SUPPORT':
                // Full WAC reward, reward is based on rank position (1x)
                wacReward = baseReward;
                // Hype decay: -1.0/day, min 1.0
                newMultiplier = Math.max(1.0, m.multiplier - 1.0);
                break;

            case 'REFORM': {
                // WAC reward × reform time multiplier
                const reformMul = getReformMultiplier(m.daysSinceJoin);
                wacReward = Math.round(baseReward * reformMul * 1_000_000) / 1_000_000;
                // Multiplier is set by time tier (not incremental)
                newMultiplier = reformMul;
                break;
            }

            case 'PROTEST':
                // Full WAC (RAC temporarily disabled)
                wacReward = baseReward;
                newMultiplier = 1.0; // PROTEST stays at 1.0
                break;

            case 'EMERGENCY':
                // No rewards
                break;
        }

        return {
            userId: m.userId,
            campaignId: m.campaignId,
            effectiveWac: m.effectiveWac,
            rank,
            wacReward,
            newMultiplier,
        };
    });
}

// ─── Campaign-level reward (legacy — still used for dailyRankingPoints) ─────

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

export function computeDailyPool(totalSystemStaked: number): number {
    if (totalSystemStaked <= 0) return 0;
    return Math.sqrt(totalSystemStaked) * 2;
}

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

// ─── Legacy exports (backward compat) ───────────────────────────────────────

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
