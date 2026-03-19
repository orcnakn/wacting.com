declare module 'rbush' {
  interface BBox {
    minX: number;
    minY: number;
    maxX: number;
    maxY: number;
  }

  class RBush<T extends BBox> {
    constructor(maxEntries?: number);
    insert(item: T): this;
    remove(item: T, equals?: (a: T, b: T) => boolean): this;
    clear(): this;
    search(bbox: BBox): T[];
    all(): T[];
    load(items: T[]): this;
    toBBox(item: T): BBox;
    compareMinX(a: T, b: T): number;
    compareMinY(a: T, b: T): number;
    toJSON(): object;
    fromJSON(data: object): this;
  }

  export default RBush;
}
