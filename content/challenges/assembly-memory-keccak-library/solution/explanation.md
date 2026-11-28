# Reference Solution Explanation

## Memory rules the solution relies on

- `0x00..0x3f`: scratch space, free to use between statements.
- `0x40`: free memory pointer. Memory at and behind it is unallocated.
- `0x60`: the zero slot, used as the initial value of empty dynamic arrays. Never write it.
- A `bytes memory` value is a pointer to a length word followed by the data.

## copy, slice, concat

All three allocate at the free memory pointer, store the length and copy 32 bytes per loop
iteration. A word-wise loop can run past the logical end of the data when the length is
not a multiple of 32. Two things make that safe:

1. the overshoot lands in memory the function is allocating anyway;
2. after copying, one `mstore(tail, 0)` at the logical end clears the padding, and the
   free memory pointer is rounded up to the next word boundary.

`concat` restarts the destination pointer at `result + 32 + len(a)` before copying `b`,
so the overshoot of the first loop is overwritten by the start of `b`.

`slice` performs its bounds check as `start > total || length > total - start`. Writing it
as `start + length > total` overflows for large arguments and would let the check pass.

## Hash functions

- `hashPair` and `hashPacked` write exactly 64 bytes into the scratch space.
- `hashPacked` builds its first word as `shl(96, account) | (amount & (2^96 - 1))`. The
  shift discards anything above the address, the mask anything above the amount. Values
  that pass through assembly can carry dirty upper bits, and assembly does not clean them
  automatically.
- `hashTriple` needs 96 bytes. Writing a third word at `0x40` would destroy the free
  memory pointer, so the data is written behind the pointer and the pointer is not moved.
- `hashConcat` builds the concatenation behind the free memory pointer in the same way.

## Pitfalls

- Forgetting to update `0x40` after building an array: the next allocation overwrites it.
- Assuming free memory is zero. It may contain leftovers from earlier temporary use, so
  the padding has to be cleared explicitly.
- Returning the input pointer from `copy` or from a full-range `slice`.
- Copying byte by byte with `mstore8`, which costs roughly thirty times more gas.
