import { describe, it, expect } from 'vitest';
import { calculateSize, computeIconAreaM2, computeAuraRadius, BASE_SIZE, FOLLOWER_WEIGHT, AREA_PER_WAC_M2 } from '../../src/engine/growth_calculator';

describe('GrowthCalculator', () => {
    it('Returns base size with 0 followers', () => {
        expect(calculateSize(0)).toBe(BASE_SIZE);
    });

    it('Scales linearly with followers', () => {
        // 10 followers = 10 * 0.5 + 1.0 base = 6.0
        expect(calculateSize(10)).toBe(6.0);
    });

    it('Applies FOLLOWER_WEIGHT per follower', () => {
        expect(calculateSize(1)).toBe(BASE_SIZE + FOLLOWER_WEIGHT);
        expect(calculateSize(2)).toBe(BASE_SIZE + 2 * FOLLOWER_WEIGHT);
    });

    it('Computes icon area from WAC balance', () => {
        expect(computeIconAreaM2(100)).toBe(100 * AREA_PER_WAC_M2);
    });

    it('Computes aura radius from area', () => {
        const area = 100 * AREA_PER_WAC_M2;
        const expected = Math.sqrt(area / Math.PI);
        expect(computeAuraRadius(area)).toBeCloseTo(expected, 5);
    });
});
