# Whitelists: Background

## Membership with a mapping

`mapping(address => bool)` is the simplest allow-list: one storage slot per address and a constant
cost lookup. Its limits are that members cannot be enumerated or counted on chain. If a count is
needed, keep a separate counter and update it only when a flag actually flips.

## Idempotence

An operation is idempotent when repeating it has no further effect. List management should be
idempotent or should revert on repeats; either way the stored flag and any derived counter must
stay consistent. Returning a `bool changed` lets callers see which case occurred.

## Arrays in calldata

```solidity
function addBatch(address[] calldata accounts) external { ... }
```

`calldata` arrays are read directly from the transaction input without being copied to memory,
which is the cheapest way to accept a list. Batch functions save the fixed per-transaction cost
when many entries are changed. Their loops are bounded by the caller's own input and gas, so they
cannot be used to block other users.

## Atomicity

A transaction either completes or reverts as a whole. When a batch reverts on a bad element, the
elements processed before it are rolled back too.

## Guarding functions

A modifier such as `onlyAllowed` turns the list into an access rule. Keep roles separate: the
right to manage a list and the right granted by being on it are different permissions.

## Scaling note

Storing every address on chain costs gas per entry. For very large lists, a Merkle root with
per-user proofs or a bitmap keyed by index is cheaper; those are separate techniques.
