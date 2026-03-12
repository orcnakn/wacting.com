import { describe, it, expect, vi } from 'vitest';
import { tickMovement, IconState } from '../../src/engine/movement_engine';
import * as brownian from '../../src/utils/brownian';

function makeIcon(overrides: Partial<IconState> = {}): IconState {
    return {
        id: 'mock-1',
        userId: 'user-1',
        x: 100, y: 100,
        vx: 0, vy: 0,
        baseSpeed: 1.0,
        size: 1.0,
        wacBalance: 0,
        exploreMode: 0,
        ...overrides,
    };
}

describe('MovementEngine', () => {
    it('Keeps coordinates within world bounds after tick', () => {
        const icon = makeIcon({ x: brownian.GRID_WIDTH - 0.1, y: 10 });

        // Run multiple ticks; position must always stay in-bounds
        for (let i = 0; i < 20; i++) {
            tickMovement(icon, 0.2);
            expect(icon.x).toBeGreaterThanOrEqual(0);
            expect(icon.x).toBeLessThan(brownian.GRID_WIDTH);
            expect(icon.y).toBeGreaterThanOrEqual(0);
            expect(icon.y).toBeLessThan(brownian.GRID_HEIGHT);
        }
    });

    it('Wraps coordinates around the world toroidally', () => {
        // Place icon near right edge, force vx positive via Math.random mock
        const icon = makeIcon({ x: brownian.GRID_WIDTH - 0.1, y: 10, exploreMode: 0 });

        // stepSize for City (exploreMode=0) is 0.5
        // Mock Math.random to return 1.0 → (1 - 0.5) * 0.5 = +0.25 for vx
        vi.spyOn(Math, 'random').mockReturnValue(1.0);
        tickMovement(icon, 0.2);
        vi.restoreAllMocks();

        expect(icon.x).toBeGreaterThanOrEqual(0);
        expect(icon.x).toBeLessThan(brownian.GRID_WIDTH);
    });

    it('Position changes each tick', () => {
        const icon = makeIcon({ x: 50, y: 50 });
        const before = { x: icon.x, y: icon.y };
        tickMovement(icon, 1.0);
        // With random motion, position almost certainly changes
        // (probability of no movement is essentially zero)
        const moved = icon.x !== before.x || icon.y !== before.y;
        expect(moved).toBe(true);
    });
});
