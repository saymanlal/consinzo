# Staking Rewards with rewardPerToken Accounting

## Problem Statement

Implement `StakingRewards` in `src/StakingRewards.sol`. Users stake `stakingToken`. The owner
funds reward periods in `rewardsToken`; during a period the pool distributes `rewardRate`
reward tokens per second, shared among stakers in proportion to their stake at each moment.
Every operation must run in constant time, regardless of the number of stakers.

## Interface

```solidity
constructor(address stakingToken_, address rewardsToken_, uint256 duration_)

function lastTimeRewardApplicable() public view returns (uint256)
function rewardPerToken() public view returns (uint256)
function earned(address account) public view returns (uint256)

function stake(uint256 amount) external
function withdraw(uint256 amount) external
function getReward() public returns (uint256 reward)
function exit() external
function notifyRewardAmount(uint256 reward) external
```

Public state declared in the starter: `stakingToken`, `rewardsToken`, `owner`, `duration`,
`periodFinish`, `rewardRate`, `lastUpdateTime`, `rewardPerTokenStored`,
`userRewardPerTokenPaid(address)`, `rewards(address)`, `totalSupply`, `balanceOf(address)`.

## Rules

1. `lastTimeRewardApplicable()` is `min(block.timestamp, periodFinish)`.
2. `rewardPerToken()` is the cumulative reward per staked token, scaled by `1e18`:
   - if `totalSupply == 0` it returns `rewardPerTokenStored`;
   - otherwise `rewardPerTokenStored +
     (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / totalSupply`.
3. `earned(account)` is
   `balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18 + rewards[account]`.
4. `stake`, `withdraw`, `getReward`, `exit` and `notifyRewardAmount` first update
   `rewardPerTokenStored` and `lastUpdateTime` (to `lastTimeRewardApplicable()`), and the first
   four also settle the caller (`rewards[caller] = earned(caller)`,
   `userRewardPerTokenPaid[caller] = rewardPerTokenStored`).
5. `stake(amount)`: reverts with `ZeroAmount()` for zero; pulls staking tokens; increases
   `balanceOf` and `totalSupply`; emits `Staked(user, amount)`.
6. `withdraw(amount)`: reverts with `ZeroAmount()` for zero and `InsufficientBalance()` if
   `amount > balanceOf[caller]`; returns staking tokens; emits `Withdrawn(user, amount)`.
7. `getReward()`: pays the caller's settled rewards, sets them to zero, returns the amount and
   emits `RewardPaid(user, reward)`. If nothing is owed it returns `0` without reverting and
   without transferring.
8. `exit()`: withdraws the caller's entire stake (if any) and then calls `getReward()`.
9. `notifyRewardAmount(reward)`: only `owner` (`NotOwner()` otherwise). Pulls `reward` reward
   tokens from the owner with `transferFrom`, then:
   - if `block.timestamp >= periodFinish`: `rewardRate = reward / duration`;
   - otherwise: `rewardRate = (reward + (periodFinish - block.timestamp) * rewardRate) / duration`;
   - reverts with `RewardTooSmall()` if the resulting `rewardRate` is zero;
   - sets `lastUpdateTime = block.timestamp` and `periodFinish = block.timestamp + duration`;
   - emits `RewardAdded(reward)`.
10. Rewards that elapse while `totalSupply == 0` are not attributed to anyone.
11. Token transfers that return `false` revert with `TransferFailed()`.

## What the tests check

- Exact `earned` values for one and for several stakers who join and leave at different times.
- That accrual stops at `periodFinish` and resumes correctly after a new notification.
- Roll-over of the undistributed remainder when a period is topped up early.
- Revert paths, owner-only funding, and that the pool never pays more than it was funded.
