import { describe, it, expect, vi } from 'vitest';
import { MovementEngine, tickMovement, IconState } from '../../src/engine/movement_engine';
import * as brownian from '../../src/utils/brownian';

describe('MovementEngine', () => {
    it('Wraps coordinates around the world toroidally', () => {
        // If an icon moves past GRID_WIDTH, it should wrap to 0.
        const icon: IconState = {
            id: '1',
            x: brownian.GRID_WIDTH - 0.5,
            y: 10,
            vx: 10, // Move right fast
            vy: 0,
            baseSpeed: 1.0,
            size: 1.0
        };

        tickMovement(icon, 0.2); // dt = 0.2

        // x = 714.5 + (10 * 0.85 + noise) * 1.0 * 0.2 
        // It should definitely cross 715 and wrap around to a small positive number
        expect(icon.x).toBeLessThan(brownian.GRID_WIDTH);
        expect(icon.x).toBeGreaterThanOrEqual(0);
        // Specifically because vx was high positive, it wraps:
        // newVx = 10 * 0.85 = 8.5
        // deltaX = 8.5 * 0.2 = 1.7
        // rawX = 714.5 + 1.7 = 716.2 -> wraps to 1.2
        expect(icon.x).toBeCloseTo(1.2, 0);
    });

    it('Damps velocity over time if no new noise is applied', () => {
        // Mock gaussianRandom to return 0 to isolate damping
        vi.spyOn(brownian, 'gaussianRandom').mockReturnValue(0);

        const icon: IconState = {
            id: '1',
            x: 100, y: 100,
            vx: 10, vy: 10,
            baseSpeed: 1.0, size: 1.0
        };

        tickMovement(icon, 0.2);

        // Damping is 0.85, so vx should become 8.5
        expect(icon.vx).toBe(8.5);
        expect(icon.vy).toBe(8.5);

        vi.restoreAllMocks();
    });
});
