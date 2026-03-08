import { describe, it, expect } from 'vitest';
import {
    getTierBonus,
    computeDailyReward,
    computeAllRewards,
    BASE_REWARD,
} from '../../src/engine/reward_calculator.js';

describe('getTierBonus', () => {
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

describe('computeDailyReward', () => {
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
        expect(r.toString()).toBe('1.5'); // no spurious decimals
    });
});

describe('computeAllRewards', () => {
    const makeUser = (userId: string, rank: number, usersBelow: number) => ({
        userId, rank, usersBelow,
    });

    it('computes rewards for all users correctly', () => {
        const users = [
            makeUser('top', 1, 2),      // 3 total users → usersBelow=2 → tier N<100 → 1 WAC
            makeUser('mid', 2, 1),      // 1 WAC
            makeUser('bot', 3, 0),      // 1 WAC
        ];
        const entries = computeAllRewards(users, 0);
        expect(entries.every((e) => e.rewardWac === 1)).toBe(true);
    });

    it('respects maxSupply cap', () => {
        const users = [makeUser('A', 1, 0)];
        const entries = computeAllRewards(users, 85_016_666_666_666, 85_016_666_666_667);
        // Only 1 WAC left in supply → should return 1
        expect(entries[0]!.rewardWac).toBe(1);
    });

    it('returns 0 reward when max supply exhausted', () => {
        const users = [makeUser('A', 1, 0)];
        const entries = computeAllRewards(users, 85_016_666_666_667, 85_016_666_666_667);
        expect(entries[0]!.rewardWac).toBe(0);
    });

    it('handles large tier reward', () => {
        const users = [makeUser('whale', 1, 1_500_000)]; // tier 40+1=41 WAC
        const entries = computeAllRewards(users, 0);
        expect(entries[0]!.rewardWac).toBe(41);
    });
});
