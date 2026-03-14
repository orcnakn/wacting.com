import { describe, it, expect } from 'vitest';
import {
    getTierBonus,
    computeDailyReward,
    computeDailyPool,
    computeAllCampaignRewards,
    computeRacDecay,
    BASE_REWARD,
} from '../../src/engine/reward_calculator.js';

describe('getTierBonus (legacy)', () => {
    it('returns 0 for N = 0–99', () => {
        expect(getTierBonus(0)).toBe(0);
        expect(getTierBonus(50)).toBe(0);
        expect(getTierBonus(99)).toBe(0);
    });

    it('returns 0.5 for N = 100–999', () => {
        expect(getTierBonus(100)).toBe(0.5);
        expect(getTierBonus(500)).toBe(0.5);
        expect(getTierBonus(999)).toBe(0.5);
    });

    it('returns 2 for N = 1,000–9,999', () => {
        expect(getTierBonus(1000)).toBe(2);
        expect(getTierBonus(9999)).toBe(2);
    });

    it('returns 5 for N = 10,000–99,999', () => {
        expect(getTierBonus(10_000)).toBe(5);
        expect(getTierBonus(99_999)).toBe(5);
    });

    it('returns 15 for N = 100,000–999,999', () => {
        expect(getTierBonus(100_000)).toBe(15);
        expect(getTierBonus(999_999)).toBe(15);
    });

    it('returns 40 for N >= 1,000,000', () => {
        expect(getTierBonus(1_000_000)).toBe(40);
        expect(getTierBonus(999_999_999)).toBe(40);
    });
});

describe('computeDailyReward (legacy)', () => {
    const cases: Array<[number, number]> = [
        [0, 1],     // base only
        [99, 1],
        [100, 1.5],
        [999, 1.5],
        [1_000, 3],
        [9_999, 3],
        [10_000, 6],
        [99_999, 6],
        [100_000, 16],
        [999_999, 16],
        [1_000_000, 41],
    ];

    it.each(cases)(
        'N=%i → %f WAC/day',
        (usersBelow, expectedReward) => {
            expect(computeDailyReward(usersBelow)).toBe(expectedReward);
        }
    );

    it('returns result with 6dp precision', () => {
        const r = computeDailyReward(100);
        expect(r.toString()).toBe('1.5');
    });
});

describe('computeDailyPool (new tokenomics)', () => {
    it('returns 0 for zero staked', () => {
        expect(computeDailyPool(0)).toBe(0);
    });

    it('returns sqrt(100) * 2 = 20 for 100 WAC staked', () => {
        expect(computeDailyPool(100)).toBeCloseTo(20, 6);
    });

    it('returns sqrt(10000) * 2 = 200 for 10000 WAC staked', () => {
        expect(computeDailyPool(10000)).toBeCloseTo(200, 6);
    });

    it('grows sub-linearly (logarithmic growth)', () => {
        const pool100 = computeDailyPool(100);
        const pool10000 = computeDailyPool(10000);
        // 100x more staked → only 10x more reward (sqrt)
        expect(pool10000 / pool100).toBeCloseTo(10, 1);
    });
});

describe('computeAllCampaignRewards', () => {
    const makeCampaign = (id: string, leaderId: string, staked: number) => ({
        campaignId: id,
        leaderId,
        totalWacStaked: staked,
    });

    it('distributes proportionally to campaigns', () => {
        const campaigns = [
            makeCampaign('c1', 'leader1', 75),
            makeCampaign('c2', 'leader2', 25),
        ];
        const entries = computeAllCampaignRewards(campaigns);

        // Total staked = 100 → daily pool = sqrt(100)*2 = 20
        const totalReward = entries.reduce((s, e) => s + e.rewardWac, 0);
        expect(totalReward).toBeCloseTo(20, 4);

        // c1 gets 75%, c2 gets 25%
        expect(entries[0]!.rewardWac).toBeCloseTo(15, 4);
        expect(entries[1]!.rewardWac).toBeCloseTo(5, 4);
    });

    it('returns empty array for no campaigns', () => {
        expect(computeAllCampaignRewards([])).toEqual([]);
    });

    it('handles single campaign', () => {
        const campaigns = [makeCampaign('c1', 'l1', 100)];
        const entries = computeAllCampaignRewards(campaigns);
        expect(entries[0]!.rewardWac).toBeCloseTo(20, 4);
        expect(entries[0]!.sharePercent).toBe(1);
    });

    it('respects maxSupply cap', () => {
        const campaigns = [makeCampaign('c1', 'l1', 100)];
        // Only 5 WAC left in supply
        const entries = computeAllCampaignRewards(campaigns, 95, 100);
        expect(entries[0]!.rewardWac).toBe(5);
    });

    it('returns 0 reward when supply exhausted', () => {
        const campaigns = [makeCampaign('c1', 'l1', 100)];
        const entries = computeAllCampaignRewards(campaigns, 100, 100);
        expect(entries[0]!.rewardWac).toBe(0);
    });
});

describe('computeRacDecay (-1 Rule)', () => {
    it('decays by protestorCount per day', () => {
        const result = computeRacDecay({
            campaignId: 'c1',
            poolId: 'p1',
            totalRacBalance: 100n,
            protestorCount: 10,
            dailyRankingPoints: 0,
        });
        expect(result.decayAmount).toBe(10n);
        expect(result.netDecay).toBe(10n);
        expect(result.newBalance).toBe(90n);
        expect(result.shouldDeactivate).toBe(false);
    });

    it('life-water: ranking points offset decay', () => {
        const result = computeRacDecay({
            campaignId: 'c1',
            poolId: 'p1',
            totalRacBalance: 100n,
            protestorCount: 10,
            dailyRankingPoints: 15, // more than decay → no decay
        });
        expect(result.netDecay).toBe(0n);
        expect(result.newBalance).toBe(100n);
    });

    it('partial offset: net decay = protestors - ranking', () => {
        const result = computeRacDecay({
            campaignId: 'c1',
            poolId: 'p1',
            totalRacBalance: 1000n,
            protestorCount: 100,
            dailyRankingPoints: 40,
        });
        // Net decay = 100 - 40 = 60
        expect(result.netDecay).toBe(60n);
        expect(result.newBalance).toBe(940n);
    });

    it('deactivates pool when balance reaches zero', () => {
        const result = computeRacDecay({
            campaignId: 'c1',
            poolId: 'p1',
            totalRacBalance: 5n,
            protestorCount: 10,
            dailyRankingPoints: 0,
        });
        // Can only decay 5 (not 10)
        expect(result.netDecay).toBe(5n);
        expect(result.newBalance).toBe(0n);
        expect(result.shouldDeactivate).toBe(true);
    });
});
