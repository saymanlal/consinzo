# Multi-Pool Reward Farm with Allocation Points

## Problem Statement

Implement `RewardFarm` in `src/RewardFarm.sol`. The farm emits `rewardPerSecond` reward tokens
from `startTime` on. The owner registers staking pools, each for a different LP token and with
a number of allocation points. At any moment a pool receives the fraction
`allocPoint / totalAllocPoint` of the emission, and inside a pool the reward is shared pro rata
to stake. All user operations must be O(1).

The reward tokens are transferred to the farm in advance by the owner.

## Interface

```solidity
constructor(address rewardToken_, uint256 rewardPerSecond_, uint256 startTime_)

function poolLength() external view returns (uint256)
function add(uint256 allocPoint, address lpToken) external returns (uint256 pid)
function set(uint256 pid, uint256 allocPoint) external
function updatePool(uint256 pid) public
function massUpdatePools() public
function pendingReward(uint256 pid, address user) external view returns (uint256)
function deposit(uint256 pid, uint256 amount) external
function withdraw(uint256 pid, uint256 amount) external
function emergencyWithdraw(uint256 pid) external
```

Public state declared in the starter: `rewardToken`, `rewardPerSecond`, `startTime`, `owner`,
`totalAllocPoint`,
`poolInfo(uint256) returns (lpToken, allocPoint, lastRewardTime, accRewardPerShare, totalStaked)`
and `userInfo(uint256 pid, address user) returns (amount, rewardDebt)`.

## Rules

1. `accRewardPerShare` is scaled by `1e18` (`ACC_PRECISION`).
2. `updatePool(pid)`:
   - does nothing if `block.timestamp <= lastRewardTime`;
   - if `totalStaked == 0` or `allocPoint == 0`, only sets `lastRewardTime = block.timestamp`;
   - otherwise
     `reward = (block.timestamp - lastRewardTime) * rewardPerSecond * allocPoint / totalAllocPoint`,
     `accRewardPerShare += reward * 1e18 / totalStaked`, `lastRewardTime = block.timestamp`.
3. `massUpdatePools()` calls `updatePool` for every pool.
4. `add(allocPoint, lpToken)`: only owner (`NotOwner()`); `DuplicatePool()` if the LP token is
   already registered; updates all pools **before** changing `totalAllocPoint`; the new pool's
   `lastRewardTime` is `max(block.timestamp, startTime)`; returns the new pool id (ids are
   `0, 1, 2, ...`); emits `PoolAdded(pid, lpToken, allocPoint)`.
5. `set(pid, allocPoint)`: only owner; updates all pools before changing the pool's points and
   `totalAllocPoint`; emits `PoolSet(pid, allocPoint)`.
6. `pendingReward(pid, user)` returns what the user could claim now, including rewards accrued
   since the pool's last update (computed without modifying state, with the same formulas).
7. `deposit(pid, amount)`: updates the pool, pays the caller's pending reward (if any), pulls
   `amount` LP tokens (if `amount > 0`), updates `amount`, `totalStaked` and `rewardDebt`.
   `deposit(pid, 0)` is a harvest. Emits `Deposit(user, pid, amount)`.
8. `withdraw(pid, amount)`: `InsufficientBalance()` if `amount` exceeds the caller's stake;
   otherwise like `deposit` but returning LP tokens. Emits `Withdraw(user, pid, amount)`.
9. `emergencyWithdraw(pid)`: updates the pool, then returns the caller's whole stake without
   paying rewards and resets the caller's `amount` and `rewardDebt` to zero. Forfeited rewards
   stay in the farm; they are not redistributed to the remaining stakers. Emits
   `EmergencyWithdraw(user, pid, amount)`.
10. `rewardDebt` is always `amount * accRewardPerShare / 1e18` after an operation.
11. Every function taking a `pid` reverts with `InvalidPool()` for an unknown id.
12. `totalStaked` is tracked per pool in storage; LP tokens sent to the farm directly are
    ignored. Token transfers that return `false` revert with `TransferFailed()`.

## What the tests check

- The split between pools by allocation points and between users by stake.
- That `add` and `set` only affect rewards from that moment on.
- No rewards before `startTime` or while a pool is empty.
- Harvest, partial withdrawal, emergency withdrawal, access control and revert paths.
- That the total paid never exceeds the total emitted.
