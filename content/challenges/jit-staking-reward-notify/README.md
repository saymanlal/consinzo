# Stop Just-in-Time Staking Around Reward Notifications

`StreamedRewards` is a staking pool. Once a week a distributor calls
`notifyRewardAmount(amount)` to hand protocol revenue to stakers.

## The bug

The starter adds `amount / totalStaked` to the reward-per-token accumulator in the same
transaction. The whole reward belongs to whoever is staked at that instant. The notification
is visible in the mempool, so an attacker:

1. stakes nine times the pool's stake just before the notification,
2. lets the notification execute,
3. claims and withdraws in the same block.

The attacker takes 90% of a week's revenue without ever being exposed to the pool.

## Your task

Change the distribution model in `src/StreamedRewards.sol`: a notified reward is streamed
linearly over `DURATION` and earned in proportion to stake and time. Keep the interface.

```solidity
uint256 public constant DURATION = 7 days;

constructor(address stakeToken_, address rewardToken_, address distributor_);
function stake(uint256 amount) external;
function withdraw(uint256 amount) external;
function getReward() external returns (uint256 paid);
function notifyRewardAmount(uint256 amount) external;      // distributor only
function earned(address account) external view returns (uint256);
function rewardPerToken() external view returns (uint256);
function lastTimeRewardApplicable() external view returns (uint256); // min(block.timestamp, periodFinish)
function rewardRate() external view returns (uint256);     // reward tokens per second
function periodFinish() external view returns (uint256);
```

### Required behaviour

- `notifyRewardAmount(amount)` pulls `amount` reward tokens from the distributor
  (`NotDistributor()` for other callers, `ZeroAmount()` for zero) and then:
  - if no period is running (`block.timestamp >= periodFinish`):
    `rewardRate = amount / DURATION`;
  - otherwise: `rewardRate = (amount + (periodFinish - block.timestamp) * rewardRate) / DURATION`,
    using the rate from before the call;
  - sets `periodFinish = block.timestamp + DURATION`.
  Rewards accrued up to the call are settled at the old rate first.
- While a period runs, `rewardPerToken` grows by `elapsed * rewardRate * 1e18 / totalStaked`,
  where elapsed time stops at `periodFinish`. Nothing accrues while `totalStaked == 0`, and
  it does not revert in that case.
- A notification must not change `earned(account)` for any account in the block it happens.
- `stake` / `withdraw` revert with `ZeroAmount()` for zero; `withdraw` reverts with
  `InsufficientStake()` above the caller's stake. `getReward` pays out accrued rewards.

## What the tests check

- Staking just before a notification and leaving in the same block earns nothing; leaving one
  block later earns one block's worth.
- A staker who stays for the whole period receives the stream, split by stake and time.
- The top-up formula, the end of the period, and solvency (`rewardRate * DURATION` never
  exceeds what was notified).
