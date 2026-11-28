# Reference Solution Explanation

## Why one node per level is enough

Leaves are filled strictly from left to right. Look at the path from the new leaf at
position `index` up to the root. At level `i` the node on the path is

- a **left** child when bit `i` of `index` is 0. Everything to its right has not been
  filled yet, so its sibling is the empty subtree `zeros[i]`.
- a **right** child when bit `i` is 1. Its sibling is a subtree that is completely filled
  and will never change again.

So the only stored nodes ever needed are the latest left child of each level. `insert`
writes `_filled[i]` whenever it passes a left child and reads it whenever it passes a right
child. That is `depth` hashes and at most `depth` storage writes per insertion.

## Root history

Roots live in a ring buffer with `historySize` slots and a cursor. The constructor puts the
empty-tree root into slot 0. Each insertion advances the cursor modulo `historySize` and
overwrites the oldest root. `isKnownRoot` scans the buffer and rejects `bytes32(0)` first,
because slots that were never written are zero.

## Pitfalls

- Checking fullness with `nextIndex < 2 ** depth` in a type that cannot hold `2 ** 32`.
  The reference keeps `nextIndex` as `uint256`.
- Updating `_filled[i]` for right children. A right child completes a subtree one level
  up; overwriting the cached left sibling corrupts later roots.
- Forgetting the empty root in the history, or reporting zero as a known root.
- Treating a zero leaf as "nothing inserted". The position is consumed even though the
  root does not change.
- Recomputing the zero hashes on every insertion instead of caching them.
