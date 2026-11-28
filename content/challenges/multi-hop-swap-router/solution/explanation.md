# Reference Solution Explanation

## Quoting

For a constant-product pair with a 0.3% input fee, the output of an exact input is

```
out = in * 997 * reserveOut / (reserveIn * 1000 + in * 997)
```

rounded down. Rounding down matters: the pair verifies
`(balance0 * 1000 - in0 * 3) * (balance1 * 1000 - in1 * 3) >= reserve0 * reserve1 * 1000^2`
and an output one unit too large fails that check.

`getAmountsOut` walks the path. For each hop it looks the pair up in the factory, reads the
reserves and orients them: the reserves come back as `(reserve0, reserve1)` for the pair's
sorted tokens, so `path[i] == pair.token0()` decides which is the input side. Getting this
wrong gives plausible-looking numbers in one direction and wrong ones in the other, which is
why the tests swap both ways through the same pair.

## Execution

1. Deadline check first, so that a stale transaction fails cheaply and deterministically.
2. Quote the whole path and compare the final amount with `amountOutMin`.
3. `transferFrom(user, firstPair, amountIn)`.
4. For hop `i`, call `pair.swap` with the quoted output on the output side. The recipient is
   the pair of hop `i + 1`, or `to` on the last hop.

Sending each output directly to the next pair saves one transfer per hop and means the router
has no balance that could be stolen or stranded. Because every pair receives exactly the input
that was used for its quote, each constant-product check passes.

All quotes are taken from the reserves before any hop executes. That is exact as long as
every pair appears at most once in the path, which is the supported case. A path that uses the
same pair in two consecutive hops (`[A, B, A]`) would make the pair its own recipient and is
rejected by the pair.

## Pitfalls

- Checking the minimum output after the swaps works too, but wastes gas on failures; checking
  it against a re-read balance instead of the quote makes the function depend on the
  recipient's previous balance.
- Using `>=` for the deadline rejects a transaction mined exactly at the deadline.
- Pulling the input into the router and then forwarding it requires an extra approval-free
  transfer and leaves funds in the router if a later step is skipped.
- A missing pair must be reported as `PairNotFound()`; calling `getReserves` on `address(0)`
  reverts without a reason.
