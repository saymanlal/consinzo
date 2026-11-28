# Pausable Switch With Modifiers

## Problem Statement

Implement `PausableSwitch` in `src/PausableSwitch.sol`. The owner can pause and unpause the
contract. Two functions depend on the switch:

- `ping()` is the normal action and works only while the contract is **not** paused.
- `emergencyReset()` is a recovery action and works only while the contract **is** paused.

The checks must be written as the modifiers `whenNotPaused` and `whenPaused`.

## Required Interface

```solidity
error NotOwner(address caller);
error EnforcedPause();
error ExpectedPause();

event Paused(address account);
event Unpaused(address account);
event Pinged(address indexed account, uint256 totalPings);
event PingsReset(uint256 clearedPings);

function owner() external view returns (address);
function paused() external view returns (bool);
function totalPings() external view returns (uint256);
function pingsOf(address account) external view returns (uint256);

function pause() external;
function unpause() external;
function ping() external;
function emergencyReset() external;
```

## Rules

1. The deployer is the owner. The contract starts unpaused.
2. `whenNotPaused` reverts with `EnforcedPause()` if the contract is paused.
   `whenPaused` reverts with `ExpectedPause()` if the contract is not paused.
3. `pause()`: owner only, `whenNotPaused`. Sets `paused = true` and emits `Paused(msg.sender)`.
4. `unpause()`: owner only, `whenPaused`. Sets `paused = false` and emits `Unpaused(msg.sender)`.
5. `ping()`: anyone, `whenNotPaused`. Increases `pingsOf[msg.sender]` and `totalPings` by one and
   emits `Pinged(msg.sender, totalPings)`.
6. `emergencyReset()`: owner only, `whenPaused`. Sets `totalPings` to zero and emits
   `PingsReset(previousTotal)`. Per-account counts in `pingsOf` are not changed.
7. On owner-only functions a non-owner always gets `NotOwner(msg.sender)`, whatever the pause
   state. The owner check comes first.

## What the Tests Check

- `ping` works while running and reverts with `EnforcedPause` while paused.
- `emergencyReset` reverts with `ExpectedPause` while running and works while paused.
- Pausing twice and unpausing twice revert with the matching error.
- Non-owners cannot pause, unpause or reset in any state.
