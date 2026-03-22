/**
 * growth_calculator.ts
 *
 * Icon sizing is driven by campaign WAC staking.
 * RAC protest pools temporarily disabled.
 */

export const MIN_ICON_SIZE = 1.0;       // minimum visual size (never zero)

/**
 * Computes the effective campaign size from WAC staked.
 */
export function computeEffectiveSize(totalWacStaked: number): number {
    return Math.max(0, totalWacStaked);
}

/**
 * Computes the visual display size of a campaign icon.
 */
export function calculateSize(totalWacStaked: number): number {
    const effective = computeEffectiveSize(totalWacStaked);
    return MIN_ICON_SIZE + effective;
}
