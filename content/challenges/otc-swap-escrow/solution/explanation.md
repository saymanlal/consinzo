# Reference Solution Explanation

## State

Each order keeps its original `sellAmount` and `buyAmount` (these define the price and never
change), the `remaining` escrowed amount and an `active` flag. Ids come from a counter, so a
never-created id reads as a zeroed struct with `active == false`, and the same
`OrderNotActive()` check covers unknown, filled and cancelled orders.

## Fill

```
cost = ceil(take * buyAmount / sellAmount)
```

- The price is taken from the original amounts. Quoting from `remaining` would change the
  price after the first partial fill.
- The division rounds up. With rounding down a taker could split a fill into amounts for which
  `take * buyAmount < sellAmount` and pay nothing at all. Rounding up guarantees that the sum of
  payments over any split is at least the asked total, and `cost >= 1` whenever `take >= 1`.
- Storage is updated first; then the buy tokens move from taker to maker and the sell tokens
  from escrow to taker. If either transfer fails the whole call reverts, so a failed payment
  leaves the order unchanged.
- The payment goes directly to the maker, so the escrow only ever holds unfilled sell tokens.

## Cancel

Only the maker can cancel, only while active. `remaining` is zeroed and the flag cleared before
the refund is sent, which makes a second cancel (or a fill) fail.

## Isolation

The contract may hold the same token for many orders. Every outgoing transfer is bounded by the
order's own `remaining`, so one order can never spend another order's escrow.

## Pitfalls

- Forgetting to deactivate a fully filled order lets the maker "cancel" it and creates
  confusing zero refunds.
- Checking the maker before the active flag makes unknown ids report `NotMaker`.
- Fee-on-transfer or rebasing tokens would break the `remaining` accounting; the exercise
  assumes standard ERC-20 behaviour.
