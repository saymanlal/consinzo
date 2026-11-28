# Reference Solution Explanation

## Root cause

The distributor had two payout paths, and both sent ETH while `rewardDebt` was stale:

- `claim()` paid, then wrote `rewardDebt`.
- `settle()` paid and relied on the vault to call `sync()` later.

The `nonReentrant` modifiers did not help because the dangerous second call arrives through
a different contract. During `claim()`'s payment the vault is unlocked, and
`vault.withdraw` legitimately calls `distributor.settle`, which has no lock and sees the
same `pending` value. In the other direction, during `settle()`'s payment the distributor's
own lock is not held (the outer call entered the vault), so a direct `claim()` succeeds.

## Fix

Both paths now go through one internal function:

```solidity
function _harvest(address user) internal {
    uint256 amount = pending(user);
    rewardDebt[user] = balanceOf(user) * accRewardPerShare / PRECISION;
    _pay(user, amount);
}
```

The debt is updated before the transfer. While the recipient's code runs, `pending(user)`
is zero, so any nested `claim`, `settle` (via `deposit` or `withdraw`) or combination of them
pays nothing. `sync` still runs after the vault changes the balance and re-bases the debt on
the new stake.

The fix is purely an ordering change, so honest nested use (for example a contract that
restakes inside its `receive`) keeps working.

## Alternatives and pitfalls

- Putting `nonReentrant` on `settle` as well also blocks the first attack, but it makes any
  vault operation started from a reward callback revert, and it must share the lock with
  `claim` to be effective. It does not cover the `settle` -> `claim` direction unless the
  lock is taken in `settle` too.
- A lock in the vault cannot protect state that lives in the distributor.
- Do not move `sync` before the balance change: the debt must be computed from the new
  stake.
