# Reference Solution Explanation

## Structure

The contract tracks three kinds of ETH:

- `subscriptions[x].balance`: prepaid by subscriber `x`, still theirs;
- `merchantBalance`: already charged, owed to the merchant;
- the invariant `address(this).balance == merchantBalance + sum of subscriber balances`.

`subscribe` and `charge` move `price` from the first kind to the second. `withdraw` and `collect`
are the only functions that send ETH, each paying out exactly one of those numbers after zeroing
it.

## `paidUntil` as the billing clock

`paidUntil` is the end of the last period that was paid for. A charge is allowed when
`block.timestamp >= paidUntil` and moves the clock forward by exactly one period:

```solidity
s.paidUntil += period;
```

This single line gives three properties:

- one charge per period: after a charge, `paidUntil` is in the future (unless the merchant is
  catching up) and the next call reverts with `NotDue()`;
- no drift: a merchant who charges ten days late does not push the subscriber's schedule back by
  ten days;
- bounded catch-up: after `n` unbilled periods the merchant can charge at most `n` times.

## Pitfalls

- **`paidUntil = block.timestamp + period` in `charge`.** It looks equivalent and is not: every
  late charge then donates the delay to the subscriber.
- **Charging more than one period per call.** A loop that bills all arrears at once is a different
  product; here each call is one period, so a subscriber's exposure per transaction is `price`.
- **Withdrawing while active.** If subscribers could withdraw at any time, the prepayment would
  guarantee nothing. The balance is locked while the subscription is active and released by
  `cancel`, which either side can call.
- **Sharing one balance.** Paying the merchant from `address(this).balance` instead of
  `merchantBalance` would let the merchant take other subscribers' prepaid funds.
