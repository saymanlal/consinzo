# Reference Solution Explanation

## The problem with a bare cast

Solidity 0.8 checks arithmetic (`+`, `-`, `*`) for overflow, but an explicit conversion is not
arithmetic. `uint64(x)` is defined as "keep the low 64 bits", so `uint64(2**64)` is `0` and no
revert happens. A contract that packs a large deposit into a small field this way records a
smaller number than was paid.

## The checks

Each `toUintN` compares the input with `type(uintN).max` and reverts with `CastOverflow(N, value)`
when it is larger. Only after the comparison is the cast performed, at which point it is known not
to discard anything. Returning the bit width and the offending value in the error makes a failed
transaction self-explanatory.

## fits

`value >> bits == 0` asks whether any bit at position `bits` or above is set. This form is used
rather than `value < 2 ** bits` because a shift cannot revert, and `bits` is a `uint8`, so the
shift distance is at most 255 and always meaningful. `value <= (1 << bits) - 1` would also work
for every `uint8` width.

## Why a library with internal functions

Internal library functions are inlined into the contract that uses them, so there is no external
call and no separate deployment. `using SafeCastLib for uint256;` lets callers write
`amount.toUint128()`, which reads naturally at the point where the narrowing happens.

## Pitfalls

- Checking after the cast (`uint64 r = uint64(value); if (r > max) ...`). The cast has already
  thrown the evidence away.
- Comparing with `>=` and rejecting the maximum itself.
- Reverting with the wrong width, or with the truncated value instead of the original one.
