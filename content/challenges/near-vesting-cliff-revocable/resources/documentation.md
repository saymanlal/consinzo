# Vesting on NEAR: background

## Time
`near.blockTimestamp()` returns the block time in nanoseconds as a `bigint`. All schedule parameters in this challenge use the same unit, so no conversion is needed. Never mix `number` and `bigint` in arithmetic; TypeScript rejects it and JavaScript throws at run time.

## Cliff and linear vesting
A vesting schedule is described by a start, a cliff and a total duration. Before `start + cliff` nothing is vested. At the cliff the amount jumps to the linear value for the elapsed time (not to zero), and from there it grows linearly until the end.

```
vested(t) = 0                              if t < start + cliff
          = total                          if t >= start + duration
          = total * (t - start) / duration otherwise
```

## Integer math
bigint division truncates toward zero. Multiply first, divide last. The remainder that truncation leaves behind is recovered at the end of the schedule because the final branch returns the exact total.

## Revocation
A revocable grant lets the grantor take back tokens that have not vested yet, for example when an employee leaves. Vested tokens always belong to the beneficiary. A common implementation freezes the schedule at the vested amount and refunds the rest in the same call.

## Pull payments
On NEAR a native transfer is a promise that can fail independently of the calling receipt. This challenge credits an internal ledger instead; a production contract would pair the ledger with a withdraw method and a callback that restores the credit when the transfer fails.
