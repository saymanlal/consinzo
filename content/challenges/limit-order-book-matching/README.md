# On-Chain Limit Order Book with Price-Time Priority

## Problem Statement

Implement `OrderBook` in `src/OrderBook.sol`: a central limit order book for one
`base`/`quote` token pair. Orders are matched by price first and by arrival time second, and
any unfilled remainder rests in the book.

The struct, errors, events and state variables are provided in the starter.

## Units

`price` is the number of quote units per one base unit (both in the tokens' smallest
units). The quote value of a trade is `amount * price` with no rounding.

## Book Structure

- Each side is a doubly linked list of orders identified by `orderId` (`prev` / `next`, with
  `0` meaning "none").
- `bestBid` is the head of the buy list: highest price first. `bestAsk` is the head of the
  sell list: lowest price first.
- Orders with the same price are ordered by arrival: a new order is inserted behind every
  resting order with an equal or better price.
- Ids start at `1` and are assigned from `nextOrderId` only when an order actually rests.

## Required Interface

```solidity
function placeLimitOrder(bool isBuy, uint256 price, uint256 amount)
    external
    returns (uint256 orderId, uint256 filled);
function cancelOrder(uint256 orderId) external;

function orders(uint256 id) external view
    returns (address owner, bool isBuy, uint256 price, uint256 remaining, uint256 prev, uint256 next);
function bestBid() external view returns (uint256);
function bestAsk() external view returns (uint256);
function nextOrderId() external view returns (uint256);
```

## Rules

### placeLimitOrder

1. Revert with `InvalidOrder` if `price == 0` or `amount == 0`.
2. Matching. While the incoming order has amount left and the head of the opposite list
   crosses (`ask.price <= price` for a buy, `bid.price >= price` for a sell):
   - `fill = min(incoming remaining, maker.remaining)`, traded at the **maker's** price.
   - Buy taker: `fill * makerPrice` quote goes from the taker to the maker's owner and
     `fill` base goes from the book to the taker.
   - Sell taker: `fill` base goes from the taker to the maker's owner and
     `fill * makerPrice` quote goes from the book to the taker.
   - A completely filled maker is unlinked and deleted (its `owner` reads as `address(0)`);
     otherwise its `remaining` decreases and it keeps its position.
   - Emit `Trade(makerOrderId, taker, makerPrice, fill)`.
3. Remainder. If amount is left, it becomes a resting order: escrow `remaining * price` quote
   (buy) or `remaining` base (sell) from the caller, insert it, emit
   `OrderPlaced(orderId, owner, isBuy, price, remaining)`.
4. Return the id of the resting order (`0` if nothing rests) and the base amount filled.

### cancelOrder

Only the order's owner may cancel; otherwise, and for ids that do not exist or are already
filled or cancelled, revert with `NotOrderOwner`. Unlink and delete the order, refund the
remaining escrow (`remaining * price` quote for a buy, `remaining` base for a sell) and emit
`OrderCancelled(orderId, remaining)`.

### Invariants

- The book's token balances equal the escrow of the resting orders: the sum of
  `remaining * price` over bids in quote and the sum of `remaining` over asks in base.
- After any call the book is not crossed: `bestBid.price < bestAsk.price` when both exist.
- A failed token transfer reverts the whole call.

## What the Tests Check

Sorting and linking of both lists, time priority, maker-price execution, sweeps across
several price levels that stop at the limit, partial fills on both sides, cancellation at
the head, middle and tail, id assignment, balance conservation and all revert paths.
