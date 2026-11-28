# Reference Solution Explanation

## Finding the price

Demand is a step function that only falls at bid prices, and supply only rises at ask
prices. The executable volume `min(demand, supply)` can therefore only change at a price
that appears in an order, so checking each order price as a candidate is exhaustive. With
at most 40 orders the quadratic scan runs on a memory copy of the book and is cheap.

The comparison implements the three-level rule directly: larger volume wins; with equal
non-zero volume the smaller imbalance wins; with equal imbalance the lower price wins.
Candidates with zero volume never replace the initial state, so an uncrossed book ends with
price and volume zero.

## Allocation

At the clearing price one side may offer more than `V`. That side is rationed by price and
then by time: `_allocate` repeatedly picks the best unserved eligible order (strict
comparison on price, so the lower id wins among equals) and fills as much as is left. The
short side is fully served by the same routine. Because both calls distribute exactly `V`,
the base that sellers deliver equals the base that buyers receive, and the quote that buyers
pay (`V * P`) equals what sellers receive.

## Settlement arithmetic

Bids were escrowed at their limit price. The refund `amount * price - filled * P` returns
both the unfilled part and the price improvement in one expression. Asks get their unfilled
base back. There is no division anywhere, so the contract balance is exactly zero after all
claims.

## Pitfalls

- Charging buyers their own limit price turns the auction into a discriminatory one and
  leaves quote stuck in the contract.
- Considering only bid prices (or only ask prices) as candidates misses the best price in
  some books.
- Letting cancelled orders contribute a candidate price or depth.
- Rationing by submission order alone lets a low bid be filled ahead of a higher one.
- Allowing cancellation after the deadline lets a trader withdraw once the outcome is known.
