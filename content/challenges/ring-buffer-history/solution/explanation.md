# Reference Solution Explanation

- **One counter drives everything**: `totalPushed` counts all pushes ever made. Push number `n`
  (counting from zero) is written to slot `n % capacity`. While the buffer is filling, that is the
  next free slot. Once it is full, it is the slot holding the oldest value, so overwriting it drops
  exactly the right element. No head or tail pointer needs to be stored separately.
- **Length**: `min(totalPushed, capacity)`.
- **Chronological read**: the buffer holds pushes `totalPushed - length` through
  `totalPushed - 1`. Logical index `i` is push number `totalPushed - length + i`, stored at that
  number modulo `capacity`. The same formula works before and after the buffer wraps.
- **Constant-cost push**: one storage write for the value and one for the counter, regardless of
  capacity. Nothing is shifted.
- **Slots in a mapping**: a mapping avoids the length bookkeeping of a dynamic array. A
  pre-sized `uint256[]` would work equally well.
- **Bounds**: `at` checks against the logical length, not the capacity, so slots that were never
  written (or stale slots) cannot be read.

## Pitfalls

- Computing the oldest position as `totalPushed % capacity` unconditionally. That is only correct
  once the buffer is full; before that the oldest value is in slot `0`.
- Bounds-checking `at` against `capacity`, which returns zeros for unwritten slots.
- Shifting all elements on each push, which makes the cost proportional to the capacity.
- Returning storage order from `toArray` instead of chronological order.
