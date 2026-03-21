/**
 * growth_calculator.ts  (Revised for Campaign-based Tokenomics)
 *
 * Icon sizing is driven by campaign WAC staking minus RAC protest pools.
 *
 * Rules:
 *   - Campaign effective size = totalWacStaked - racPool.totalBalance
 *   - Minimum size is always MIN_ICON_SIZE (icons never fully disappear)
 */

export const MIN_ICON_SIZE = 1.0;       // minimum visual size (never zero)

/**
 * Computes the effective campaign size (WAC staked minus RAC protest).
 * This is the core tokenomics formula: 1 WAC = +1, 1 RAC = -1.
 */
export function computeEffectiveSize(totalWacStaked: number, racPoolBalance: number): number {
    return Math.max(0, totalWacStaked - racPoolBalance);
}

/**
 * Computes the visual display size of a campaign icon.
 * Based on effective WAC (staked - RAC protest).
 */
export function calculateSize(totalWacStaked: number, racPoolBalance: number): number {
    const effective = computeEffectiveSize(totalWacStaked, racPoolBalance);
    return MIN_ICON_SIZE + effective;
}
