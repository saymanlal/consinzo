# Checkpoint Rewards Before Changing the Reward Rate

`RateStaking` distributes `rewardRate` reward tokens per second among stakers, pro rata to
their stake. It uses the usual accumulator: `rewardPerTokenStored` grows by
`elapsed * rewardRate * 1e18 / totalStaked`, and each account remembers the accumulator
value it was last settled at.

## The bug

`setRewardRate` overwrites `rewardRate` and nothing else. The time between `lastUpdateTime`
and the rate change has not been added to the accumulator yet, so it is later paid at the
*new* rate.

- Raising the rate from 1 to 10 tokens per second after 1000 quiet seconds credits 10 000
  tokens instead of 1000. The pool was only funded for the real schedule, so the last
  stakers to claim cannot be paid.
- Lowering the rate removes rewards stakers had already earned.

## Your task

Patch `src/RateStaking.sol`. Keep the interface unchanged.

```solidity
constructor(address stakeToken_, address rewardToken_, uint256 rewardRate_); // deployer is owner
function stake(uint256 amount) external;
function withdraw(uint256 amount) external;
function claim() external returns (uint256 paid);
function setRewardRate(uint256 newRate) external;   // owner only
function earned(address account) external view returns (uint256);
function rewardPerToken() external view returns (uint256);
```

### Rules

- Every second is paid at the rate that was in force during that second. Calling
  `setRewardRate` must not change `earned(account)` for any account at that instant.
- `setRewardRate` is owner-only (`NotOwner()`). Setting the rate to zero stops accrual and
  keeps everything already earned claimable.
- Time during which nothing is staked earns nothing for anyone, before or after a rate change.
- `stake` and `withdraw` revert with `ZeroAmount()` for zero, and `withdraw` reverts with
  `InsufficientStake()` above the caller's stake.
- `claim` pays the caller's accrued rewards and returns the amount.

## What the tests check

- `earned` is unchanged by a rate increase and by a rate decrease, and continues at the new
  rate afterwards.
- Several rate changes, several stakers and empty-pool periods produce exact totals.
- A pool funded for the true schedule can pay every staker in full.
