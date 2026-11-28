# Reference Solution Explanation

## Accounting

For each pool the farm keeps `accRewardPerShare`: the total reward one staked LP token has
earned since the pool was created, scaled by `1e18`. `updatePool` advances it:

```
reward            = elapsed * rewardPerSecond * allocPoint / totalAllocPoint
accRewardPerShare += reward * 1e18 / totalStaked
```

A user who holds `amount` since the accumulator was `acc0` has earned
`amount * (acc - acc0) / 1e18`. Instead of storing `acc0`, the farm stores
`rewardDebt = amount * acc0 / 1e18`; the pending reward is
`amount * acc / 1e18 - rewardDebt`. Every operation that changes `amount` first pays the
pending reward and then recomputes `rewardDebt` with the new amount.

`pendingReward` uses the same private helper (`_currentAcc`) as `updatePool`, so the view and
the state-changing path cannot diverge.

## Pool management

The pool's share `allocPoint / totalAllocPoint` appears inside `updatePool`. If `add` or `set`
changed the weights first, the next update of every other pool would apply the new weights to
seconds that elapsed under the old ones. Both functions therefore call `massUpdatePools()`
before touching `totalAllocPoint`. The hidden tests detect a missing mass update by comparing
exact reward amounts across a weight change.

A new pool starts at `max(now, startTime)`, and `updatePool` returns early while
`block.timestamp <= lastRewardTime`, so nothing accrues before the start time.

## Idle periods

When `totalStaked == 0` the reward for that period cannot be assigned to anyone; the pool only
advances `lastRewardTime`. The same branch handles pools with zero allocation points and avoids
a division by zero when `totalAllocPoint` is zero.

## Other decisions

- `totalStaked` is stored per pool rather than read from `lpToken.balanceOf(farm)`. A direct
  transfer of LP tokens therefore cannot dilute stakers, and a pool whose LP token equals the
  reward token would not count the reward budget as stake.
- `emergencyWithdraw` updates the pool before removing the stake. The leaving user's share of
  the elapsed period is forfeited and stays in the farm instead of being redistributed.
- User records are written before any token transfer.
- `_pool(pid)` gives the specified `InvalidPool()` error instead of an array panic.

## Rounding

Both divisions round down, so the sum of all payments is at most the amount emitted to pools
that had stakers. The farm must be funded with at least `rewardPerSecond` times the intended
running time.
