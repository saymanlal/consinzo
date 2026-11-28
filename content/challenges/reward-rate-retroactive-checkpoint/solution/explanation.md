# Why the patch works

The accumulator is lazy. `rewardPerToken()` returns

```
rewardPerTokenStored + (now - lastUpdateTime) * rewardRate * 1e18 / totalStaked
```

so the interval `[lastUpdateTime, now]` is always "pending" and is priced with whatever
`rewardRate` holds when somebody finally settles. That is correct only if the rate was
constant over the interval. `stake`, `withdraw` and `claim` keep `totalStaked` constant over
the pending interval by settling first; the starter forgets to do the same for the rate.

The reference settles before it writes:

```solidity
_checkpoint();          // rewardPerTokenStored = rewardPerToken(); lastUpdateTime = now
rewardRate = newRate;
```

After the checkpoint the pending interval is empty, so the new rate can only apply to future
time. No per-account work is needed: accounts are settled lazily against the accumulator,
and the accumulator is now exact.

## Pitfalls

- Updating `lastUpdateTime` without first storing `rewardPerToken()` discards the pending
  interval entirely. Stakers then lose rewards on every rate change.
- Using the `updateReward(address(0))` idiom works too, as long as the global part of the
  modifier runs. The reference factors that part into `_checkpoint()` to make the intent
  explicit.
- When `totalStaked == 0` the accumulator does not move but `lastUpdateTime` still must, or
  the empty period would be paid to the next staker.
