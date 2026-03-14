/**
 * growth_calculator.ts  (Revised for Campaign-based Tokenomics)
 *
 * Icon sizing is driven by campaign WAC staking minus RAC protest pools.
 *
 * Rules:
 *   - Campaign effective size = totalWacStaked - racPool.totalBalance
 *   - Icon area = effective size × AREA_PER_WAC_M2
 *   - Aura radius = sqrt(areaM2 / π)
 *   - Minimum size is always MIN_ICON_SIZE (icons never fully disappear)
 */

export const AREA_PER_WAC_M2 = 6;      // 1 WAC = 6 m²
export const MIN_ICON_SIZE = 1.0;       // minimum visual size (never zero)

/**
 * Computes the effective campaign size (WAC staked minus RAC protest).
 * This is the core tokenomics formula: 1 WAC = +1, 1 RAC = -1.
 *
 * @param totalWacStaked  - Total WAC locked in the campaign by members
 * @param racPoolBalance  - Total RAC deposited in the protest pool against this campaign
 */
export function computeEffectiveSize(totalWacStaked: number, racPoolBalance: number): number {
    return Math.max(0, totalWacStaked - racPoolBalance);
}

/**
 * Computes the icon area in m² from effective campaign size.
 */
export function computeIconAreaM2(effectiveSize: number): number {
    return effectiveSize * AREA_PER_WAC_M2;
}

/**
 * Computes the equivalent circular radius (in map units) for a given area.
 * Useful for rendering aura circles on the map.
 *
 * @param areaM2 - Area in m² (from computeIconAreaM2)
 * @param mapScale - How many map units per metre (default 1)
 */
export function computeAuraRadius(areaM2: number, mapScale = 1): number {
    if (areaM2 <= 0) return 0;
    return Math.sqrt(areaM2 / Math.PI) * mapScale;
}

/**
 * Computes the visual display size of a campaign icon.
 * Based on effective WAC (staked - RAC protest).
 *
 * @param totalWacStaked  - Total WAC locked by campaign members
 * @param racPoolBalance  - Total RAC in protest pool (0 if no pool)
 */
export function calculateSize(totalWacStaked: number, racPoolBalance: number): number {
    const effective = computeEffectiveSize(totalWacStaked, racPoolBalance);
    return MIN_ICON_SIZE + effective;
}

/**
 * Computes the collective influence area for the platform's top campaigns.
 * Called once per snapshot / real-time cache refresh.
 *
 * @param campaigns - Array of { totalWacStaked, racPoolBalance } for top N campaigns
 */
export function computeTopNCampaignArea(
    campaigns: Array<{ totalWacStaked: number; racPoolBalance: number }>,
    n = 100
): number {
    let totalEffective = 0;
    for (let i = 0; i < Math.min(campaigns.length, n); i++) {
        totalEffective += computeEffectiveSize(
            campaigns[i]!.totalWacStaked,
            campaigns[i]!.racPoolBalance
        );
    }
    return totalEffective * AREA_PER_WAC_M2;
}
