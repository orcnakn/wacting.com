/**
 * Helper: generates a random number from a standard normal distribution (mean 0, variance 1)
 * using the Box-Muller transform.
 */
export function gaussianRandom(): number {
    let u = 0, v = 0;
    while (u === 0) u = Math.random();
    while (v === 0) v = Math.random();
    return Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
}

export const GRID_WIDTH = 715;
export const GRID_HEIGHT = 714;

/**
 * Bounds a coordinate onto the toroidal plane mapping (wraps around).
 */
export function wrapCoordinate(value: number, max: number): number {
    return ((value % max) + max) % max;
}
