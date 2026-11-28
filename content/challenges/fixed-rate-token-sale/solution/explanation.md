# Reference Solution Explanation

## Approach

`buy()` is a straight checks-effects-interactions function:

1. Reject a zero payment, then compare the cumulative totals against the two caps. The
   comparisons use `>` so that landing exactly on a cap is allowed.
2. Write `totalRaised` and `contributed[msg.sender]` before calling the token.
3. Transfer `msg.value * rate / 1e18` tokens and check the boolean result.

`withdraw()` sends `address(this).balance` with a low-level `call` and checks the result.
It leaves `totalRaised` untouched, which is what makes the hard cap a lifetime limit rather
than a limit on the current balance.

## Pitfalls

- **Comparing against the balance instead of `totalRaised`.** After the owner withdraws, a
  balance-based cap would let the sale raise the cap again.
- **Dividing before multiplying.** `weiAmount / 1e18 * rate` returns zero for every purchase
  below 1 ETH.
- **Off-by-one on the caps.** `>=` rejects the purchase that exactly fills the cap.
- **Wrong check order.** The specification fixes the order (zero, hard cap, buyer limit) so
  that callers get a deterministic error when a purchase breaks both caps.
- **Ignoring the token's return value.** A token that returns `false` would otherwise take
  the buyer's ETH and deliver nothing.
- If the sale runs out of inventory the token transfer reverts and the whole purchase is
  rolled back, including the accounting writes, so no ETH is taken.
