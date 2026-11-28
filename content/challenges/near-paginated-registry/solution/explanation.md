# Solution Explanation: NEAR Paginated Item Registry

1. **One helper for the window.** `pageEnd` validates `fromIndex` and `limit`, caps the limit at `MAX_PAGE_SIZE` and returns `min(fromIndex + limit, length)`. Both view methods then run a simple `for (i = fromIndex; i < end; i++)` loop. When `fromIndex >= length`, `end <= fromIndex` and the loop body never runs, which produces the empty page without a special case.
2. **Cap versus reject.** A large limit is a normal request ("give me as many as you allow"), so it is reduced silently. A limit below 1 or a fractional value is a caller bug and is rejected. `fromIndex` is checked first so the reported error is deterministic.
3. **Owner index.** A global list cannot be filtered by owner without scanning every item, and the scan would not have a bounded cost. A second list per owner (`owner:position -> global id`, plus a per-owner count) makes owner pagination the same bounded loop over a different sequence.
4. **Bounded work.** Each view reads at most 50 items regardless of how large the registry grows, which is the reason pagination exists: view calls also have gas limits.

## Pitfalls
- Returning `limit` entries padded with `null` or throwing when the page runs past the end.
- Throwing for `fromIndex >= total` instead of returning an empty array.
- Implementing `getItemsByOwner` by filtering a global page, which makes pages shorter than requested and skips items.
- Treating `fromIndex` in `getItemsByOwner` as a global id.
