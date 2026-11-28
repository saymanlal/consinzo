# Payment Streams

## Concept

A payment stream replaces a lump-sum payment with a continuous one. The payer escrows the whole
amount up front; the contract releases it to the payee at a constant rate over a time window.
ERC-1620 describes this model. Typical uses are salaries, subscriptions and vesting.

## Linear release

With deposit `D`, start `t0` and stop `t1`, the amount earned at time `t` is

```
earned(t) = D * clamp(t - t0, 0, t1 - t0) / (t1 - t0)
```

No transaction is needed for the stream to progress: the contract evaluates the formula
whenever someone asks. The recipient's withdrawals are tracked separately, so the available
amount is `earned(t) - withdrawn`.

## Cancellation

Stopping a stream early is a settlement at time `t`: the payee keeps `earned(t)`, the payer
gets `D - earned(t)` back. Computing the refund as "deposit minus earned" rather than with a
second division guarantees that no base unit is created or lost.

## Rounding

`D * elapsed / duration` truncates. The truncated part is not lost: it becomes available later
in the stream, and at `t >= t1` the full deposit is earned.

## Shared escrow

One contract holds the deposits of all streams. Each stream must be limited to its own deposit
by its own accounting, because the token balance alone cannot tell the streams apart.
