# Token Timelock Vault with Independent Locks

## Problem Statement

Implement `TimelockVault` in `src/TimelockVault.sol`. A user deposits ERC-20 tokens into a
lock that cannot be withdrawn before its unlock time. A user may hold many locks at once; each
lock is independent and is identified by its index in that user's list of locks.

## Interface

```solidity
constructor(address token_)

function lock(uint256 amount, uint256 unlockTime) external returns (uint256 lockId)
function extendLock(uint256 lockId, uint256 newUnlockTime) external
function withdraw(uint256 lockId) external
function withdrawMatured() external returns (uint256 total)

function lockCount(address user) external view returns (uint256)
function getLock(address user, uint256 lockId)
    external view returns (uint256 amount, uint256 unlockTime, bool withdrawn)
function lockedBalance(address user) external view returns (uint256)
function withdrawableBalance(address user) external view returns (uint256)
```

Public state declared in the starter: `token`, `totalLocked`.

## Rules

1. `lock(amount, unlockTime)`:
   - reverts with `ZeroAmount()` if `amount == 0`;
   - reverts with `InvalidUnlockTime()` if `unlockTime <= block.timestamp`;
   - pulls `amount` tokens from the caller, appends a lock to the caller's list and returns its
     index (the first lock of every user has id `0`);
   - increases `totalLocked`; emits `Locked(user, lockId, amount, unlockTime)`.
2. `extendLock(lockId, newUnlockTime)` acts on the caller's lock:
   - reverts with `InvalidLock()` if `lockId >= lockCount(caller)`;
   - reverts with `AlreadyWithdrawn()` if the lock was withdrawn;
   - reverts with `InvalidUnlockTime()` unless `newUnlockTime` is strictly greater than both the
     current unlock time and `block.timestamp`;
   - emits `Extended(user, lockId, newUnlockTime)`.
3. `withdraw(lockId)` acts on the caller's lock:
   - reverts with `InvalidLock()` / `AlreadyWithdrawn()` as above;
   - reverts with `StillLocked()` if `block.timestamp < unlockTime`;
   - marks the lock withdrawn, decreases `totalLocked`, transfers the amount to the caller and
     emits `Withdrawn(user, lockId, amount)`.
4. `withdrawMatured()` withdraws every lock of the caller that is matured and not yet
   withdrawn, in a single token transfer. It emits `Withdrawn` for each lock, returns the total
   and reverts with `NothingToWithdraw()` if the total is zero.
5. Lock ids are stable: a lock keeps its id and its data after it is withdrawn
   (`withdrawn == true`).
6. `lockedBalance(user)` is the sum of all locks not yet withdrawn; `withdrawableBalance(user)`
   is the sum of those that are also matured.
7. `getLock` reverts with `InvalidLock()` for an unknown id.
8. Token transfers that return `false` revert with `TransferFailed()`.

## What the tests check

- Several locks per user with different unlock times, and isolation between users.
- Exact unlock-time boundaries.
- Extension rules, including extending a matured lock.
- Batch withdrawal skipping immature and already withdrawn locks, and no double withdrawal.
