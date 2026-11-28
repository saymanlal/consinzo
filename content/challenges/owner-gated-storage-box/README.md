# Owner-Gated Storage Box

## Problem Statement

Implement `StorageBox` in `src/StorageBox.sol`. The contract holds a single `uint256`.
Everyone may read it. Only the account that deployed the contract (the owner) may change it.

## Required Interface

```solidity
error NotOwner(address caller);
event ValueChanged(uint256 oldValue, uint256 newValue);

constructor(uint256 initialValue);

function owner() external view returns (address);
function updateCount() external view returns (uint256);
function get() external view returns (uint256);
function set(uint256 newValue) external;
```

## Rules

1. The constructor stores `initialValue` and records `msg.sender` as `owner`. The owner never changes.
   The constructor does not emit `ValueChanged` and does not count as an update.
2. `get()` returns the stored value.
3. `set(newValue)`:
   - reverts with `NotOwner(msg.sender)` when the caller is not the owner, leaving all state unchanged;
   - otherwise stores `newValue`, increases `updateCount` by one and emits
     `ValueChanged(oldValue, newValue)`.
4. Every successful `set` counts as an update, even when `newValue` equals the current value.

## What the Tests Check

- The initial value, the owner and a zero `updateCount` after deployment.
- The owner can overwrite the value repeatedly and `updateCount` follows.
- A non-owner call reverts with exactly `NotOwner(caller)` and changes nothing.
- Ownership follows the deployer, not a hard-coded address.
