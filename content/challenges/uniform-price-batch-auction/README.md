# Batch Auction with a Uniform Clearing Price

## Problem Statement

Implement `BatchAuction` in `src/BatchAuction.sol`. Traders submit limit bids and asks for a
`base`/`quote` pair until a deadline. After the deadline anyone calls `clear()`, which
computes one clearing price for the whole batch. Every matched order trades at that price,
regardless of its own limit, and unmatched escrow is returned.

The struct, errors, events and state variables are provided in the starter.

## Units

`price` is quote units per one base unit, so the quote value of `amount` base is
`amount * price` with no rounding.

## Order Phase (`block.timestamp < deadline`)

- `submitBid(price, amount)` escrows `amount * price` quote. `submitAsk(price, amount)`
  escrows `amount` base. Both return the order id, which is the index in `orders` starting at 0.
- Reverts: `AuctionClosed` at or after the deadline, `InvalidOrder` for a zero price or
  amount, `TooManyOrders` when `MAX_ORDERS` (40) orders exist.
- `cancel(orderId)`: `AuctionClosed` at or after the deadline, `NotOrderOwner` for anyone
  else, `AlreadyClaimed` if it was already cancelled. Refunds the whole escrow and sets
  `amount = 0`, `claimed = true`. A cancelled order takes no part in clearing.

## Clearing

`clear()` reverts with `AuctionStillOpen` before the deadline and with `AlreadyCleared` on a
second call. Otherwise it sets `cleared`, `clearingPrice`, `clearedVolume` and each order's
`filled`, and emits `Cleared`.

1. Candidates are the limit prices of all live (not cancelled) orders. For a candidate `p`:
   - `demand(p)` = total amount of live bids with `price >= p`;
   - `supply(p)` = total amount of live asks with `price <= p`;
   - `volume(p) = min(demand, supply)`, `imbalance(p) = |demand - supply|`.
2. The clearing price is the candidate with the largest volume. Ties are broken by the
   smallest imbalance, then by the lowest price.
3. If the largest volume is zero, nothing trades: `clearingPrice = 0`, `clearedVolume = 0`.
4. Allocation at clearing price `P` and volume `V`, done separately for each side:
   - bids with `price >= P`, ordered by highest price and then lowest id, are filled in turn
     until `V` is used up;
   - asks with `price <= P`, ordered by lowest price and then lowest id, likewise.

   The last order served on a side may be partially filled. Both sides fill exactly `V`.

## Settlement

`claim(orderId)` reverts with `NotCleared` before clearing and `AlreadyClaimed` for claimed
or cancelled orders. Anyone may call it; the tokens go to the order's owner.

- Bid: `filled` base, and `amount * price - filled * clearingPrice` quote.
- Ask: `filled * clearingPrice` quote, and `amount - filled` base.

Returns `(baseOut, quoteOut)` and emits `Claimed`. After every order is claimed the contract
holds no tokens.

## What the Tests Check

The clearing price and volume for balanced books, excess demand and excess supply, each
tie-break, independence from submission order, price-time rationing, cancelled orders,
phase enforcement, capacity, and exact token conservation.
