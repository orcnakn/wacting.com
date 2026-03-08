import { describe, it, expect } from 'vitest';
import { MovementEngine, IconState } from '../../src/engine/movement_engine';

describe('SpatialIndex', () => {
    it('Successfully returns icons within a query bounding box', () => {
        const engine = new MovementEngine();

        // Icon 1 is placed at (100, 100)
        engine.icons.set('1', { id: '1', x: 100, y: 100, vx: 0, vy: 0, baseSpeed: 1, size: 5 });
        // Icon 2 is far away at (500, 500)
        engine.icons.set('2', { id: '2', x: 500, y: 500, vx: 0, vy: 0, baseSpeed: 1, size: 5 });

        // Tick builds the spatial index
        engine.tick(0.2);

        // Query viewport closely around icon 1
        const results = engine.spatialIndex.search(90, 90, 110, 110);

        expect(results).toHaveLength(1);
        expect(results[0].id).toBe('1');
    });

    it('Correctly accounts for icon radius intersection boundaries', () => {
        const engine = new MovementEngine();

        // Placed at (10, 10) with a giant radius (size=10, radius=5) so it spans (5, 5) to (15, 15)
        engine.icons.set('giant', { id: 'giant', x: 10, y: 10, vx: 0, vy: 0, baseSpeed: 1, size: 10 });

        engine.tick(0.2);

        // Query viewport explicitly from (0, 0) to (6, 6). The center (10, 10) is not in the box,
        // but the radius minX/minY connects at (5, 5). Therefore, the box intersects the icon.
        const results = engine.spatialIndex.search(0, 0, 6, 6);

        expect(results).toHaveLength(1);
        expect(results[0].id).toBe('giant');
    });
});
