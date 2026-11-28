# String and Bytes Utilities

## Problem Statement

Implement `StringUtils` in `src/StringUtils.sol`. Solidity strings have no built-in length,
comparison or search operations. Write a small set of `pure` helpers that provide them.

All lengths in this challenge are **byte** lengths of the UTF-8 encoding, not character counts.

## Required Interface

```solidity
error LengthOutOfRange(uint256 length, uint256 min, uint256 max);

function byteLength(string calldata s) external pure returns (uint256);
function equal(string calldata a, string calldata b) external pure returns (bool);
function bytesEqual(bytes calldata a, bytes calldata b) external pure returns (bool);
function concat(string calldata a, string calldata b) external pure returns (string memory);
function concatBytes(bytes calldata a, bytes calldata b) external pure returns (bytes memory);
function startsWith(string calldata s, string calldata prefix) external pure returns (bool);
function isLengthBetween(string calldata s, uint256 min, uint256 max) external pure returns (bool);
function validateLength(string calldata s, uint256 min, uint256 max) external pure returns (uint256);
```

## Rules

1. `byteLength(s)` returns the number of bytes in `s`. `byteLength("")` is `0`.
2. `equal(a, b)` and `bytesEqual(a, b)` return `true` exactly when both inputs have the same length
   and the same content. Use `keccak256` for the content comparison.
3. `concat(a, b)` returns `a` followed by `b`. `concatBytes` does the same for byte arrays.
4. `startsWith(s, prefix)` returns `true` when the first bytes of `s` are exactly `prefix`. The
   empty prefix matches every string. A prefix longer than `s` never matches.
5. `isLengthBetween(s, min, max)` returns `true` when `min <= byteLength(s) <= max` (both bounds
   inclusive). It never reverts; if `min > max` no length can satisfy it and the result is `false`.
6. `validateLength(s, min, max)` returns the byte length of `s` when it lies in `[min, max]` and
   otherwise reverts with `LengthOutOfRange(length, min, max)`.

## What the Tests Check

- Lengths of empty, ASCII and multi-byte UTF-8 strings.
- Equality for identical, different, prefix-related and empty inputs.
- Concatenation results, including empty operands, checked by content and length.
- `startsWith` with empty, equal, longer and almost-matching prefixes.
- Both ends of the inclusive range in the validators, and the revert data.
