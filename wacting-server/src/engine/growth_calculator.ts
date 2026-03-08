/**
 * growth_calculator.ts  (Revised for WAC Economy)
 *
 * Icon sizing is now driven entirely by WAC balances.
 * No more decay model — size reflects real-time economic standing.
 *
 * Rules:
 *   - Icon area = top-100 users' total WAC × 6 m²
 *   - Individual icon size (visual radius) = base + follower bonus
 *   - Aura radius (influence area) = sqrt(areaM2 / π) — derived from top-100 total
 */

export const AREA_PER_WAC_M2 = 6;      // 1 WAC = 6 m²
export const FOLLOWER_WEIGHT = 0.5;    // visual size units per follower
export const BASE_SIZE = 1.0;          // minimum visual size

/**
 * Computes the collective influence area (m²) of the platform's top users.
 * Called once per snapshot / real-time cache refresh.
 *
 * @param top100TotalWac - Sum of wacBalance for the top N (usually 100) users
 */
export function computeIconAreaM2(top100TotalWac: number): number {
    return top100TotalWac * AREA_PER_WAC_M2;
}

/**
 * Computes the equivalent circular radius (in map units) for a given area.
 * Useful for rendering aura circles on the map.
 *
 * @param areaM2 - Area in m² (from computeIconAreaM2)
 * @param mapScale - How many map units per metre (default 1)
 */
export function computeAuraRadius(areaM2: number, mapScale = 1): number {
    return Math.sqrt(areaM2 / Math.PI) * mapScale;
}

/**
 * Computes the visual display size of an individual icon.
 * Driven by follower count (social proof) rather than own WAC balance,
 * since WAC already manifests as the shared aura area.
 *
 * @param followerCount - Icon's current follower count
 */
export function calculateSize(followerCount: number): number {
    return BASE_SIZE + followerCount * FOLLOWER_WEIGHT;
}
