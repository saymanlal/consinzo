# Reference Solution Explanation

## Approach

Each account stores three numbers: `principal`, `accrued` (rewards already earned but not paid)
and `lastUpdate`. The whole contract rests on one private helper:

```solidity
function _checkpoint(Account storage a, address user) private {
    a.accrued = pendingRewards(user);
    a.lastUpdate = block.timestamp;
}
```

`stake`, `unstake` and `claim` all call it before touching `principal`. Because interest is
linear in time for a constant principal, splitting a period at a checkpoint gives the same total
(up to one unit of rounding per checkpoint) as computing it in one piece, and the interest is
always charged on the principal that was really staked during that period.

`pendingRewards` is a view of the same formula, so the number a user sees is the number `claim`
pays.

## Reward pool

Principal and rewards share one token balance. `totalStaked` tracks the principal, and
`rewardPool()` is defined as the surplus above it. `claim()` reverts with
`InsufficientRewards()` when the payout exceeds the surplus, so one user's rewards can never be
paid out of another user's stake. The debt is kept and can be claimed once the pool is refilled.

## Pitfalls

- Updating `principal` before checkpointing charges the new principal for the old period.
- Adding claimed or accrued rewards to `principal` turns simple interest into compound interest.
- Forgetting to reset `lastUpdate` in `claim` pays the same period twice.
- Using the raw token balance as the reward budget lets early claimers drain later stakers.
- A first-time staker has `lastUpdate == 0`; this is harmless because the principal is zero, so
  the product is zero regardless of the elapsed time.
