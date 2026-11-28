# Reference Solution Explanation

## The helpers

Both helpers read the current allowance, validate the change against it and delegate to one
internal `_approve`, which performs the zero-address check, the write and the `Approval` event
(with the new total, as wallets expect).

- `increaseAllowance`: the overflow test is `addedValue > type(uint256).max - current`. The
  right-hand side cannot underflow, so the comparison itself is safe; computing
  `current + addedValue` first would panic instead of returning `AllowanceOverflow()`.
- `decreaseAllowance`: `subtractedValue > current` is the underflow test. Reverting (rather than
  clamping to zero) tells the holder that the spender has already used more than expected.

Neither helper treats `type(uint256).max` specially. The infinite convention is a property of
how `transferFrom` spends an allowance, not of how the number is edited.

## transferFrom

The allowance is read once. If it is below `amount` the call fails with
`InsufficientAllowance()` before balances are examined. If it equals `type(uint256).max` the
storage write is skipped; otherwise the reduced value is stored. `_transfer` then performs the
recipient and balance checks.

There is no shortcut for `from == msg.sender`; `transferFrom` always spends an allowance, which
keeps its behaviour identical for every caller.

## Why relative changes help

With `approve(100)` followed by `approve(50)`, a spender who sees the second transaction pending
can spend 100 first and 50 afterwards. With `decreaseAllowance(50)`, if the spender has already
spent the 100 the call reverts, and otherwise the remaining allowance is 50: the total the
spender can obtain never exceeds the original 100.

## Pitfalls

- Emitting `Approval` with the delta instead of the new total.
- Decrementing an infinite allowance, which eventually breaks integrations that approved once.
- Treating `MAX - 1` as infinite, or re-inflating a decreased allowance back to `MAX`.
