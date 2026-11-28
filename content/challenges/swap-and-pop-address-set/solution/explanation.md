# Reference Solution Explanation

- **Two structures kept in sync**: `_values` gives enumeration and `_indexPlusOne` gives O(1)
  lookup of a member's position. Every mutation updates both.
- **Index plus one**: the mapping default is `0`. Storing `position + 1` lets `0` mean "absent"
  while still allowing a member at position `0`. It also makes `address(0)` an ordinary member; no
  address value is reserved as a marker.
- **add**: one `push` and one mapping write. After the push, the array length is exactly
  `position + 1`.
- **remove (swap-and-pop)**:
  1. look up the position;
  2. if it is not the last one, copy the last element into it and give that element the removed
     element's index;
  3. `pop` the array;
  4. delete the removed element's index.
  The work is constant regardless of the set size. Enumeration order is not preserved, which is the
  accepted trade-off.
- **Order of the final delete**: the removed element's index is cleared after the swap. In the
  "already last" case no swap happens and the delete is what clears its entry.

## Pitfalls

- Storing the raw position, so that the element at position `0` looks absent.
- Forgetting to update the moved element's index. The set looks correct until that element is
  removed or queried.
- Writing `_indexPlusOne[last] = ...` after deleting the removed element's index when both are the
  same address (removing the last element), which resurrects the entry.
- Using `delete _values[index]`, which leaves a zero-address hole instead of shrinking the array.
