# NEAR Paginated Item Registry

## Objective
Implement `ItemRegistry` in `src/ItemRegistry.ts`. Accounts append named items. View methods return pages of items using the `from_index` / `limit` convention common to NEAR contracts.

## Interface

```ts
export interface Item {
  id: number;     // global index, starting at 0
  owner: string;  // near.predecessorAccountId() of addItem
  name: string;
}

export const MAX_PAGE_SIZE = 50;

addItem(name: string): number
totalItems(): number
itemCountOf(owner: string): number
getItem(id: number): Item | null
getItems(fromIndex: number, limit: number): Item[]
getItemsByOwner(owner: string, fromIndex: number, limit: number): Item[]
```

## Rules
1. `addItem(name)` requires a non-empty `name` (otherwise throw an error containing `Invalid name`), stores the item with the next global id and returns that id.
2. `getItems(fromIndex, limit)` returns the items with global ids `fromIndex`, `fromIndex + 1`, ... in ascending order.
   - `fromIndex` must be a non-negative integer, otherwise throw an error containing `Invalid from_index`.
   - `limit` must be an integer `>= 1`, otherwise throw an error containing `Invalid limit`.
   - A `limit` greater than `MAX_PAGE_SIZE` (50) is treated as 50. It is not an error.
   - The page ends at the last existing item: the result has `min(limit, 50, total - fromIndex)` items, and is empty when `fromIndex >= total`.
3. `getItemsByOwner(owner, fromIndex, limit)` applies the same rules to the sequence of items added by `owner`, in the order they were added. Here `fromIndex` is a position within that owner's sequence (0 is the owner's first item), not a global id. The returned items keep their global `id`.
4. `itemCountOf(owner)` is the number of items added by `owner`; `totalItems()` is the global count.
5. `fromIndex` is validated before `limit`.

## What the tests check
Full and partial pages, the page that starts exactly at the end, the page size cap, invalid arguments, walking a list page by page without gaps or duplicates, and owner-scoped pagination with interleaved owners.
