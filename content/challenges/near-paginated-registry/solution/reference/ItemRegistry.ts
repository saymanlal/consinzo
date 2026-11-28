import { LookupMap, near, assert } from "near-sdk-js";

export interface Item {
  id: number;
  owner: string;
  name: string;
}

export const MAX_PAGE_SIZE = 50;

export class ItemRegistry {
  private items = new LookupMap<Item>("item:");
  private total = 0;
  // owner + ":" + position -> global id of the owner's n-th item
  private ownerIndex = new LookupMap<number>("oidx:");
  private ownerCounts = new LookupMap<number>("ocnt:");

  addItem(name: string): number {
    assert(name.length > 0, "Invalid name");
    const owner = near.predecessorAccountId();
    const id = this.total;
    this.items.set(String(id), { id, owner, name });
    this.total = id + 1;

    const position = this.itemCountOf(owner);
    this.ownerIndex.set(owner + ":" + String(position), id);
    this.ownerCounts.set(owner, position + 1);
    return id;
  }

  totalItems(): number {
    return this.total;
  }

  itemCountOf(owner: string): number {
    return this.ownerCounts.get(owner) ?? 0;
  }

  getItem(id: number): Item | null {
    return this.items.get(String(id));
  }

  // Validates the paging arguments and returns the exclusive end position for a list of `length` entries.
  private pageEnd(fromIndex: number, limit: number, length: number): number {
    assert(Number.isInteger(fromIndex) && fromIndex >= 0, "Invalid from_index");
    assert(Number.isInteger(limit) && limit >= 1, "Invalid limit");
    const effective = Math.min(limit, MAX_PAGE_SIZE);
    // When fromIndex >= length the end is <= fromIndex and the caller's loop does not run.
    return Math.min(fromIndex + effective, length);
  }

  getItems(fromIndex: number, limit: number): Item[] {
    const end = this.pageEnd(fromIndex, limit, this.total);
    const page: Item[] = [];
    for (let id = fromIndex; id < end; id++) {
      const item = this.items.get(String(id));
      if (item !== null) page.push(item);
    }
    return page;
  }

  getItemsByOwner(owner: string, fromIndex: number, limit: number): Item[] {
    const end = this.pageEnd(fromIndex, limit, this.itemCountOf(owner));
    const page: Item[] = [];
    for (let position = fromIndex; position < end; position++) {
      const id = this.ownerIndex.get(owner + ":" + String(position));
      if (id === null) continue;
      const item = this.items.get(String(id));
      if (item !== null) page.push(item);
    }
    return page;
  }
}
