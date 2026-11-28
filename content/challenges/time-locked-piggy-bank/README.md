# Time-Locked Piggy Bank

## Problem Statement

Implement `PiggyBank` in `src/PiggyBank.sol`. The deployer chooses an unlock time. Anyone can add
ETH at any moment. Nothing can leave before the unlock time; from then on the owner can empty the
bank.

## Required Interface

```solidity
error NotOwner(address caller);
error UnlockTimeNotInFuture(uint256 unlockTime);
error ZeroDeposit();
error StillLocked(uint256 unlockTime);
error NothingToWithdraw();
error TransferFailed();

event Deposited(address indexed from, uint256 amount);
event Withdrawn(address indexed to, uint256 amount);

constructor(uint256 unlockTime_);

function owner() external view returns (address);
function unlockTime() external view returns (uint256);
function totalDeposited() external view returns (uint256);
function isUnlocked() external view returns (bool);
function secondsUntilUnlock() external view returns (uint256);

receive() external payable;
function deposit() external payable;
function withdraw() external;
```

## Rules

1. The constructor reverts with `UnlockTimeNotInFuture(unlockTime_)` unless
   `unlockTime_ > block.timestamp`. Otherwise it stores the unlock time and records the deployer as
   owner. Neither value can change later.
2. `deposit()` and plain ETH transfers (`receive()`) behave the same: revert with `ZeroDeposit()`
   when `msg.value == 0`, otherwise add `msg.value` to `totalDeposited` and emit
   `Deposited(msg.sender, msg.value)`. Deposits are accepted from anyone, before and after the
   unlock time.
3. `isUnlocked()` is `true` exactly when `block.timestamp >= unlockTime`.
4. `secondsUntilUnlock()` returns `unlockTime - block.timestamp` while locked and `0` once
   unlocked. It never reverts.
5. `withdraw()` checks, in this order:
   1. caller is the owner, else `NotOwner(msg.sender)`;
   2. the bank is unlocked, else `StillLocked(unlockTime)`;
   3. the balance is non-zero, else `NothingToWithdraw()`.
   It then sends the entire contract balance to the owner (reverting with `TransferFailed()` if the
   transfer fails) and emits `Withdrawn(owner, amount)`.
6. `totalDeposited` is a lifetime figure and is not reduced by withdrawals.

## What the Tests Check

- Constructor validation, including an unlock time equal to the current timestamp.
- Deposits through both entry points, from the owner and from other accounts.
- Withdrawal one second before the unlock time reverts; at the unlock time it succeeds.
- `secondsUntilUnlock` before, at and after the unlock time.
- Access control and the order of the withdrawal checks.
