# Safe Narrowing Cast Library

## Problem Statement

In Solidity an explicit conversion to a smaller unsigned type, such as `uint64(x)`, discards the
high bits without reverting. Implement the library `SafeCastLib` in `src/SafeCastLib.sol` so that
callers can narrow a `uint256` and get a revert instead of a wrong number.

## Required Interface

```solidity
library SafeCastLib {
    error CastOverflow(uint8 bits, uint256 value);

    function toUint128(uint256 value) internal pure returns (uint128);
    function toUint64(uint256 value) internal pure returns (uint64);
    function toUint32(uint256 value) internal pure returns (uint32);
    function fits(uint256 value, uint8 bits) internal pure returns (bool);
}
```

## Rules

1. `toUint128`, `toUint64` and `toUint32` return `value` unchanged in the narrower type when it
   fits, that is when `value <= type(uintN).max`.
2. When the value does not fit they revert with `CastOverflow(N, value)`, where `N` is the target
   width (`128`, `64` or `32`) and `value` is the rejected input.
3. `fits(value, bits)` returns `true` when `value` can be represented in `bits` bits, that is
   when `value < 2 ** bits`. It never reverts: `fits(v, 0)` is `true` only for `v == 0`, and
   `bits` up to `255` must work.
4. All functions are `internal` and `pure`, so the library can be used with
   `using SafeCastLib for uint256;`.

## How the Tests Call the Library

A library with internal functions cannot be called from outside, so each test file defines a
small harness contract that wraps the four functions in external ones. You only edit the library.

## What the Tests Check

- Values at and just above each type's maximum.
- The exact error arguments on overflow.
- Inputs whose low bits are zero, which a truncating cast would turn into `0`.
- `fits` for several widths, including `0` and `255`.
