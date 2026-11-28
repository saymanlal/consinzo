# Reference Solution Explanation

## Accrual

`_streamed` is a clamped linear function of time:

```
0                                         now <= start
deposit * (now - start) / (stop - start)  start < now < stop
deposit                                   now >= stop
```

The deposit and the two timestamps never change after creation, so the function is the same
for the whole life of the stream. The only mutable accounting field is `withdrawn`.

- `withdrawable = streamed - withdrawn`.
- `withdraw` checks the requested amount against that value and increases `withdrawn`.
- `cancel` computes `streamed` once and derives both payouts from it:
  `recipientAmount = streamed - withdrawn`, `senderAmount = deposit - streamed`. Therefore
  `withdrawn + recipientAmount + senderAmount == deposit` exactly, independent of rounding. The
  rounding itself favours the sender by less than one base unit.

## Lifecycle

`active` is set at creation and cleared by `cancel` or by the withdrawal that brings
`withdrawn` to `deposit`. A private `_active(id)` loader reverts with `StreamNotActive()` and
is the first statement of every function that works on an existing stream, which also covers
ids that were never created (their struct is all zeros).

## Pitfalls

- Reducing `deposit` on withdrawal, or computing the rate from the remaining balance, makes
  later accrual depend on when the recipient withdrew.
- Computing the sender's refund as `deposit * (stop - now) / duration` rounds a second time;
  the two rounded parts can then add up to one unit less than the deposit and leave dust
  locked forever.
- Missing clamps make `now - start` underflow before the start, or pay more than the deposit
  after the stop time.
- Letting the stream stay active after cancellation allows a second payout from other streams'
  funds, since all streams of a token share one balance.
- Transferring zero amounts is skipped; some tokens revert on zero transfers and it would make
  cancellation before the start impossible for them.
