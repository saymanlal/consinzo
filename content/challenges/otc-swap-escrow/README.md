# OTC Swap Escrow with Partial Fills

## Problem Statement

Implement `OtcEscrow` in `src/OtcEscrow.sol`. A maker offers `sellAmount` of `sellToken` in
exchange for `buyAmount` of `buyToken`. The sell tokens are escrowed in the contract when the
order is created. Any taker can then take all or part of the offer at the fixed price
`buyAmount / sellAmount`; the payment goes straight to the maker. The maker can cancel at any
time and receives whatever has not been taken.

## Interface

```solidity
function createOrder(address sellToken, address buyToken, uint256 sellAmount, uint256 buyAmount)
    external returns (uint256 orderId)
function quote(uint256 orderId, uint256 takeAmount) public view returns (uint256 cost)
function fill(uint256 orderId, uint256 takeAmount) external returns (uint256 cost)
function cancel(uint256 orderId) external returns (uint256 refunded)
```

Public state declared in the starter: `nextOrderId` and
`orders(uint256) returns (maker, sellToken, buyToken, sellAmount, buyAmount, remaining, active)`.

## Rules

1. `createOrder`:
   - reverts with `InvalidTokens()` if either token is `address(0)` or both are the same;
   - reverts with `ZeroAmount()` if `sellAmount == 0` or `buyAmount == 0`;
   - assigns ids `0, 1, 2, ...`, stores the order with `remaining = sellAmount` and
     `active = true`, pulls `sellAmount` of `sellToken` from the maker;
   - emits `OrderCreated(orderId, maker, sellToken, buyToken, sellAmount, buyAmount)`.
2. `quote(orderId, takeAmount)` is the amount of `buyToken` owed for `takeAmount` of
   `sellToken`, **rounded up**:
   `ceil(takeAmount * buyAmount / sellAmount)`, using the order's original amounts.
3. `fill(orderId, takeAmount)`, checks in this order:
   - `OrderNotActive()` if the order does not exist, is fully filled or was cancelled;
   - `ZeroAmount()` if `takeAmount == 0`;
   - `ExceedsRemaining()` if `takeAmount > remaining`.
   Then it reduces `remaining`, deactivates the order when `remaining` reaches zero, transfers
   `quote(orderId, takeAmount)` of `buyToken` from the taker directly to the maker, transfers
   `takeAmount` of `sellToken` to the taker, emits `OrderFilled(orderId, taker, takeAmount, cost)`
   and returns the cost.
4. `cancel(orderId)`: `OrderNotActive()` as above, then `NotMaker()` unless the caller is the
   maker. It deactivates the order, sets `remaining` to zero, returns the unfilled sell tokens
   to the maker, emits `OrderCancelled(orderId, refunded)` and returns the refunded amount.
5. Orders are independent: tokens escrowed for one order are never used for another.
6. Token transfers that return `false` revert with `TransferFailed()`.

## What the tests check

- Full and partial fills at the fixed price, by one or several takers.
- Rounding up of the taker's payment for amounts that do not divide evenly.
- Cancellation before, between and after fills.
- Revert order, inactive orders, and isolation between several open orders.
