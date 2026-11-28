# Patch a Batch Purchase That Reuses msg.value

`TicketBooth` sells tickets for ETH. The owner lists items with a price and a stock, buyers
call `buy(id)` for one ticket or `buyBatch(ids)` for several, and the owner collects the
income through `withdrawProceeds()`.

The payment check lives in the internal purchase routine, which `buyBatch` calls once per
ticket. `msg.value` is the same in every iteration, so a buyer who sends the price of one
ticket passes the check for every ticket in the batch. The `proceeds` counter is increased
for each ticket anyway and ends up larger than the ETH the contract holds. The same check
also makes honest batches with mixed prices impossible.

## Your task

Patch `src/TicketBooth.sol` so that a purchase always costs exactly the sum of the prices of
the tickets bought. Keep all signatures, errors and events.

## Required behaviour

- `buy(uint256 id)` payable: buys one ticket; reverts with `WrongPayment()` unless
  `msg.value == price(id)`.
- `buyBatch(uint256[] ids)` payable: buys one ticket for every entry of `ids`, in order. An
  id may appear several times and each occurrence consumes one unit of stock. Reverts with:
  - `EmptyBatch()` when `ids` is empty
  - `UnknownItem()` when an id was never listed
  - `SoldOut()` when an item has no stock left for an entry
  - `WrongPayment()` unless `msg.value` equals the sum of the prices of all entries. Both
    underpayment and overpayment revert; there are no refunds.
- A reverted call leaves stock, `purchased`, `proceeds` and balances untouched.
- Invariant: `proceeds` equals the ETH balance of the contract after every purchase and is
  zero after `withdrawProceeds()`.
- `listItem` and `withdrawProceeds` stay owner-only (`NotOwner()`).

## What the tests check

Public tests cover a single purchase, a correctly paid batch, a batch of five tickets paid
with the price of one, and a wrong single payment. Hidden tests use mixed prices, off-by-one
wei payments in both directions, duplicate ids against limited stock, empty and unknown
entries, and the proceeds invariant across several buyers followed by a withdrawal.
