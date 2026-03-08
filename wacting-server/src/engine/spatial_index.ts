import RBush from 'rbush';
import { IconState } from './movement_engine.js';

/**
 * RBush expects items to have minX, minY, maxX, maxY properties.
 * We wrap our IconState to fit this interface.
 */
export interface SpatialItem {
    minX: number;
    minY: number;
    maxX: number;
    maxY: number;
    icon: IconState;
}

export class SpatialIndex {
    private tree: RBush<SpatialItem>;

    constructor() {
        // 16 is a reasonable maxEntries value for general 2D points balancing query speed vs insertion 
        this.tree = new RBush<SpatialItem>(16);
    }

    /**
     * Clears the tree and bulk loads all current icons.
     * Bulk loading is O(N log N) but creates an optimally balanced tree,
     * much faster for querying than doing N insertions every tick.
     */
    public rebuild(icons: Map<string, IconState>): void {
        const items: SpatialItem[] = [];

        for (const icon of icons.values()) {
            // We will define the bounding box of an icon simply by its logical center and size radius.
            const radius = icon.size / 2;
            items.push({
                minX: icon.x - radius,
                minY: icon.y - radius,
                maxX: icon.x + radius,
                maxY: icon.y + radius,
                icon
            });
        }

        this.tree.clear();
        this.tree.load(items);
    }

    /**
     * Queries for all icons that intersect the given viewport rectangle.
     */
    public search(minX: number, minY: number, maxX: number, maxY: number): IconState[] {
        const results = this.tree.search({ minX, minY, maxX, maxY });
        return results.map(item => item.icon);
    }
}
