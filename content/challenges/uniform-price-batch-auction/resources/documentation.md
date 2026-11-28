# Batch Auction Notes

## Continuous versus batch trading

In continuous trading each order executes on arrival, so the sequence of transactions
decides who trades with whom and at what price. A batch auction collects orders for a period
and executes them together at a single price. Order of arrival inside the batch does not
affect the price, which removes the advantage of being first.

## Uniform clearing price

All matched orders trade at one price. A buyer who was willing to pay more keeps the
difference, and a seller who was willing to accept less receives more. The usual rule picks
the price at which the most volume can trade. If several prices give the same volume, the
one that leaves the least unmatched quantity is preferred, and a fixed rule (here, the lowest
price) settles any remaining tie so that the result is deterministic.

## Demand and supply curves

For a price `p`, demand is everything buyers would take at `p` or worse for them (bids at or
above `p`), and supply is everything sellers would give (asks at or below `p`). Demand
decreases and supply increases with price; the tradable volume at `p` is the smaller of the
two.

## Rationing

At the clearing price one side usually has more eligible quantity than can be matched.
Orders with better limits are served first, and orders with equal limits in order of
submission. Unserved quantity is returned.

## Escrow

Taking the worst-case payment at submission guarantees that the cleared batch can be settled
without any participant being able to default, and makes claims independent of each other.
