# Reference Solution Explanation

## Data structure

Each side of the book is a doubly linked list threaded through the `orders` mapping. The
best order is the head, so matching reads one storage pointer to find its counterparty. The
`prev` pointer makes cancellation and removal constant time.

## Matching

`_matchHead` handles one maker at a time. It reads the head of the opposite list, checks
that its price is acceptable for the taker, and fills the smaller of the two remaining
amounts at the maker's price. The maker's book state is updated before any token moves. The
loop in `placeLimitOrder` repeats until the taker is done, the book is empty or the next
maker no longer crosses. Because the lists are sorted, the first maker that does not cross
ends the search.

Makers were escrowed when they were placed, so settlement needs no refunds:

- a resting ask already put its base in the book, so the buyer pays the seller directly and
  the book hands over the base;
- a resting bid already put `remaining * price` quote in the book, so the seller delivers
  base to the buyer and the book releases exactly `fill * bidPrice` quote.

The taker never deposits more than it trades, and price improvement stays with the taker.

## Insertion

`_insert` walks while the existing order is at least as good as the new one (`>=` for bids,
`<=` for asks). Using a strict comparison instead would put a new order in front of older
orders at the same price and break time priority.

## Pitfalls

- Trading at the taker's limit price instead of the maker's price overcharges the taker and
  leaves quote in the book that belongs to nobody.
- Forgetting to update `bestBid` / `bestAsk` when the head is removed.
- Not clearing a filled order lets its owner "cancel" it later and withdraw other users' escrow.
- Resting the remainder before matching can leave a crossed book.
- Consuming an order id for an order that never rests makes ids unpredictable for integrators.

## Gas

Insertion is linear in the number of better-priced orders and matching is linear in the
number of makers consumed. A production book bounds both (price levels, hints, or a maximum
number of matches per call); that is outside the scope of this exercise.
