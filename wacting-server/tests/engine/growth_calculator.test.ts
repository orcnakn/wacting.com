import { describe, it, expect } from 'vitest';
import { calculateSize, DECAY_RATE, FOLLOWER_WEIGHT, BASE_SIZE } from '../../src/engine/growth_calculator';

describe('GrowthCalculator', () => {
    it('Returns base size with 0 followers and 0 tokens', () => {
        expect(calculateSize([], 0, Date.now())).toBe(BASE_SIZE);
    });

    it('Scales linearly with permanent followers', () => {
        // 10 followers = 5.0 size growth + 1.0 base
        expect(calculateSize([], 10, Date.now())).toBe(6.0);
    });

    it('Calculates token inflation correctly right at spend time', () => {
        const now = Date.now();
        const tokenHistory = [{ amount: 100, timestamp: now }];

        // e^0 = 1.0. Total size = 100 + 1.0 = 101.0
        expect(calculateSize(tokenHistory, 0, now)).toBe(101.0);
    });

    it('Decays token inflation exponentially over time', () => {
        const timeSpent = Date.now();
        const tokenHistory = [{ amount: 100, timestamp: timeSpent }];

        // Simulate checking 693 seconds later (~11.55 minutes later, the half-life of DECAY_RATE 0.001)
        // 0.001 * 693 = 0.693; e^-0.693 ≈ 0.5
        const now = timeSpent + (693 * 1000);

        const calculatedSize = calculateSize(tokenHistory, 0, now);
        // Should have decayed to roughly half (50) + 1 base = 51
        expect(calculatedSize).toBeGreaterThan(50);
        expect(calculatedSize).toBeLessThan(52);
    });

    it('Ignores token spends from the future', () => {
        const now = Date.now();
        const tokenHistory = [{ amount: 500, timestamp: now + 50000 }];

        expect(calculateSize(tokenHistory, 0, now)).toBe(BASE_SIZE);
    });
});
