# Reference Solution Explanation

## The accumulator

Paying `rewardRate` tokens per second to stakers pro rata means that, over a short interval
`dt` with total stake `S`, every staked token earns `rewardRate * dt / S`. Summing that quantity
over time gives `rewardPerToken`, a single global number. A user whose balance was constant
between two moments earned `balance * (rewardPerToken_now - rewardPerToken_then)`.

So the contract stores:

- `rewardPerTokenStored` and `lastUpdateTime` globally;
- for each user, the accumulator value at their last settlement (`userRewardPerTokenPaid`) and
  the rewards settled so far (`rewards`).

The private `_updateReward` helper performs the two-step update before every state change. Because
the accumulator is advanced before `totalSupply` or `rewardRate` changes, each interval is
priced with the supply and rate that were in force during it.

## Period handling

`lastTimeRewardApplicable()` clamps time to `periodFinish`, which stops accrual when the budget
is used up. `notifyRewardAmount` first advances the accumulator with the old rate, then:

- after the period: starts a fresh one with `reward / duration`;
- during the period: adds the unstreamed remainder `(periodFinish - now) * rewardRate` to the
  new amount, so nothing that was promised is lost and nothing is double counted.

Setting `lastUpdateTime = block.timestamp` matters when the previous period ended long ago:
the idle gap must not be multiplied by the new rate.

The reference pulls the reward tokens from the owner inside the call. The pool therefore always
holds at least `rewardRate * duration` for the running period, and rounding only ever leaves
dust in the pool.

## Pitfalls

- Changing `balanceOf`/`totalSupply` before updating the accumulator gives a new staker a share
  of past rewards.
- Using `block.timestamp` instead of the clamped time keeps paying after `periodFinish` and
  eventually makes `getReward` fail for the last claimers.
- Forgetting the roll-over silently destroys the remaining budget on every top-up; ignoring
  `lastUpdateTime` on a top-up pays the gap twice.
- Rewards that elapse while `totalSupply == 0` are not distributed. The reference keeps the
  well-known behaviour (they stay in the contract) rather than extending the period.
- `getReward()` must tolerate a zero amount so that `exit()` works for accounts with nothing
  to claim.
