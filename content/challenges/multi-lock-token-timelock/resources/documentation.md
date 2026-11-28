# Timelocks and Per-User Collections

## Timelocks

A timelock holds an asset until a timestamp. On-chain time is `block.timestamp` (Unix seconds).
Be explicit about the boundary: the usual convention, used here, is that the asset is available
when `block.timestamp >= unlockTime`.

## Many records per user

Solidity mappings cannot be enumerated, and a single `mapping(address => Lock)` allows only one
record per user. Two common layouts for several records are:

- `mapping(address => Lock[])`: ids are per-user indices;
- a global `mapping(uint256 => Lock)` with a counter and an `owner` field.

With per-user arrays, ownership is implied by where the record is stored, which removes a
whole class of "wrong owner" bugs.

## Stable identifiers

If other code or users refer to a record by index, the index must not change. Prefer a
tombstone flag (`withdrawn`) to deleting from the array.

## Loops

Unbounded loops are acceptable only when the party paying for the gas also controls the length
of the loop. Aggregating several payouts into one token transfer saves gas and keeps the
function's external interaction at the very end.
