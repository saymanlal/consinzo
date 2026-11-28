# Fixed-APR Single-Asset Staking

## Problem Statement

Implement `FixedAprStaking` in `src/FixedAprStaking.sol`. Users stake one ERC-20 token and earn
the same token as simple (non-compounding) interest, accrued per second at a fixed annual rate.
Rewards are paid from tokens that were transferred to the contract in addition to the staked
principal.

## Interface

```solidity
constructor(address token_, uint256 aprBps_)

function stake(uint256 amount) external
function unstake(uint256 amount) external
function claim() external returns (uint256 paid)
function pendingRewards(address user) public view returns (uint256)
function rewardPool() public view returns (uint256)
function stakedOf(address user) external view returns (uint256)
```

Public state declared in the starter: `token`, `aprBps`, `totalStaked`.

## Rules

1. Interest for a period in which the principal did not change is
   `principal * aprBps * elapsedSeconds / (10_000 * 365 days)`, rounded down.
2. Whenever a user's principal changes (`stake`, `unstake`) or the user claims, the interest
   earned so far is first added to that user's stored, unclaimed rewards and the user's
   timestamp is set to `block.timestamp`. Interest never compounds: unclaimed rewards do not
   earn interest.
3. `pendingRewards(user)` returns stored unclaimed rewards plus the interest accrued since the
   user's last checkpoint.
4. `stake(amount)` reverts with `ZeroAmount()` for `amount == 0`, pulls `amount` tokens with
   `transferFrom`, and increases the user's principal and `totalStaked`. Emits
   `Staked(user, amount)`.
5. `unstake(amount)` reverts with `ZeroAmount()` for `amount == 0` and with
   `InsufficientStake()` if `amount` exceeds the user's principal. It returns exactly `amount`
   tokens and does not pay rewards. Emits `Unstaked(user, amount)`.
6. `rewardPool()` returns `token.balanceOf(address(this)) - totalStaked`.
7. `claim()` pays the caller all pending rewards and returns the amount paid. It reverts with
   `NothingToClaim()` if nothing is pending and with `InsufficientRewards()` if the pending
   amount exceeds `rewardPool()`. Emits `Claimed(user, amount)`. Staked principal of any user
   must never be used to pay rewards.
8. Token transfers that return `false` revert with `TransferFailed()`.

## What the tests check

- Exact interest for known periods and APRs.
- Correct checkpointing when a user stakes more or unstakes part-way through.
- Independent accounting for several stakers who join at different times.
- Reward-pool protection: a claim larger than the pool reverts and principal stays withdrawable.
