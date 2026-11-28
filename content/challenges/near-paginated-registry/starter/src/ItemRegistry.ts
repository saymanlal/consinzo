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
    // TODO: reject an empty name ("Invalid name"), store the item under the next global id, record it in the owner's index, return the id
    throw new Error("Not implemented");
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
    // TODO: validate fromIndex ("Invalid from_index") then limit ("Invalid limit"), cap the limit at MAX_PAGE_SIZE and return min(fromIndex + limit, length)
    return 0;
  }

  getItems(fromIndex: number, limit: number): Item[] {
    // TODO: return the page of items starting at global id fromIndex
    throw new Error("Not implemented");
  }

  getItemsByOwner(owner: string, fromIndex: number, limit: number): Item[] {
    // TODO: return the page of the owner's items starting at the owner's position fromIndex
    throw new Error("Not implemented");
  }
}
