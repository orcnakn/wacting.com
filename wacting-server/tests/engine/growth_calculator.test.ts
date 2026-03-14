import { describe, it, expect } from 'vitest';
import {
    calculateSize,
    computeIconAreaM2,
    computeAuraRadius,
    computeEffectiveSize,
    computeTopNCampaignArea,
    MIN_ICON_SIZE,
    AREA_PER_WAC_M2,
} from '../../src/engine/growth_calculator';

describe('GrowthCalculator (Campaign-based Tokenomics)', () => {
    it('Returns min size with 0 WAC staked and 0 RAC', () => {
        expect(calculateSize(0, 0)).toBe(MIN_ICON_SIZE);
    });

    it('Size grows with WAC staked', () => {
        expect(calculateSize(10, 0)).toBe(MIN_ICON_SIZE + 10);
    });

    it('RAC reduces effective size (1 WAC = +1, 1 RAC = -1)', () => {
        expect(calculateSize(10, 3)).toBe(MIN_ICON_SIZE + 7);
    });

    it('Effective size never goes below 0', () => {
        expect(computeEffectiveSize(5, 20)).toBe(0);
        expect(calculateSize(5, 20)).toBe(MIN_ICON_SIZE);
    });

    it('Computes icon area from effective size', () => {
        const effective = computeEffectiveSize(100, 30);
        expect(computeIconAreaM2(effective)).toBe(70 * AREA_PER_WAC_M2);
    });

    it('Computes aura radius from area', () => {
        const area = 100 * AREA_PER_WAC_M2;
        const expected = Math.sqrt(area / Math.PI);
        expect(computeAuraRadius(area)).toBeCloseTo(expected, 5);
    });

    it('Aura radius is 0 for zero or negative area', () => {
        expect(computeAuraRadius(0)).toBe(0);
    });

    it('Computes top N campaign area correctly', () => {
        const campaigns = [
            { totalWacStaked: 50, racPoolBalance: 10 },  // effective: 40
            { totalWacStaked: 30, racPoolBalance: 5 },   // effective: 25
            { totalWacStaked: 20, racPoolBalance: 25 },  // effective: 0 (clamped)
        ];
        // Total effective: 40 + 25 + 0 = 65
        expect(computeTopNCampaignArea(campaigns)).toBe(65 * AREA_PER_WAC_M2);
    });
});
