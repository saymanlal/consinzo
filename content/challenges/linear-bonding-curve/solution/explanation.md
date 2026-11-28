# Reference Solution Explanation

## Pricing by difference

The reserve needed for a supply `S` is a function of `S` only. The reference implements it
once (`reserveFor`) and defines both trade prices as differences of that function:

```
buyCost(a)    = reserveFor(S + a) - reserveFor(S)
sellRefund(a) = reserveFor(S)     - reserveFor(S - a)
```

Because of this, sums of consecutive trades telescope. Buying `a` and then `b` costs
`reserveFor(S + a + b) - reserveFor(S)`, exactly the cost of buying `a + b` at once, even
though `reserveFor` itself rounds down. By induction `reserve == reserveFor(totalSupply)` after
every trade, which is the invariant the tests assert. Selling the entire supply returns the
reserve to exactly zero.

Integrating each trade on its own (for example `a * (p_start + p_end) / 2`) rounds every trade
independently. The errors accumulate, the reserve drifts away from the curve and the last
seller either cannot be paid or leaves ETH stranded.

## Units and overflow

`supply` has 18 decimals, `basePrice` and `slope` are per whole token, so the linear term
divides by `1e18` and the quadratic term by `2 * 1e36`. `slope * supply * supply` stays far
below `2^256` for any realistic supply (for a supply of `1e27` base units and a slope of `1e15`
the product is `1e69`).

## ETH handling

- `buy` treats `msg.value` as a maximum, keeps the cost and returns the excess. This is the
  buyer's slippage protection. State is updated before the refund is sent.
- `sell` takes `minRefund` as the seller's protection and pays after burning.
- `reserve` is tracked in storage instead of read from `address(this).balance`, so ETH forced
  into the contract cannot distort accounting.

## Pitfalls

- Checking `amount > totalSupply` instead of the caller's balance lets anyone burn value they do
  not own.
- Keeping all of `msg.value` breaks the invariant and overcharges buyers.
- Rounding a buy up "to be safe" breaks path independence; with the difference formulation no
  safety margin is needed, because every token is redeemed at exactly the price difference it
  was minted at.
