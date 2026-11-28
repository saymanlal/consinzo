# USD-Priced Payment Gateway Accepting ETH

## Problem Statement

A merchant prices orders in US dollars but is paid in ETH. The amount of ETH owed is only
known when the customer pays, because it depends on the ETH / USD price at that moment.

Implement `EthPaymentGateway` in `src/EthPaymentGateway.sol`. The owner registers orders
with a USD price. Anyone can pay an order in ETH; the gateway converts the USD price with a
Chainlink-style ETH / USD aggregator (`IAggregatorV3`, declared in the same file), keeps
exactly the amount due for the merchant and refunds the rest to the payer.

The aggregator used by the tests is a mock written inside the test files.

## Interface

```solidity
constructor(address feed_, uint256 maxAge_, address merchant_)

function owner() external view returns (address);      // the deployer
function merchant() external view returns (address);
function feed() external view returns (IAggregatorV3);
function maxAge() external view returns (uint256);
function proceeds() external view returns (uint256);   // wei owed to the merchant

function orders(bytes32 orderId) external view returns (uint256 usdAmount, address payer, bool paid);

function createOrder(bytes32 orderId, uint256 usdAmount) external;
function quote(bytes32 orderId) public view returns (uint256 weiDue);
function pay(bytes32 orderId) external payable;
function withdraw() external;

error ZeroAddress();
error NotOwner();
error NotMerchant();
error ZeroAmount();
error OrderExists();
error UnknownOrder();
error AlreadyPaid();
error InvalidPrice();
error StalePrice();
error InsufficientPayment(uint256 sent, uint256 due);
error TransferFailed();

event OrderCreated(bytes32 indexed orderId, uint256 usdAmount);
event OrderPaid(bytes32 indexed orderId, address indexed payer, uint256 weiPaid);
```

## Rules

1. The constructor reverts with `ZeroAddress()` if `feed_` or `merchant_` is zero.
2. `createOrder` is owner-only (`NotOwner()`). `usdAmount` is a USD value with 18 decimals
   (`25e18` is 25 dollars) and must be non-zero (`ZeroAmount()`). An `orderId` can be
   registered once (`OrderExists()`).
3. `quote(orderId)` reverts with `UnknownOrder()` for an unregistered id. Otherwise it reads
   the feed and returns the wei owed:
   `weiDue = ceil(usdAmount * 10 ** feedDecimals / answer)`.
   The division rounds **up**, so the merchant is never underpaid by rounding.
   - `InvalidPrice()` if `answer <= 0`.
   - `StalePrice()` if `updatedAt == 0`, `updatedAt > block.timestamp`, or
     `block.timestamp - updatedAt > maxAge` (an answer exactly `maxAge` old is accepted).
   `quote` still works for an order that is already paid.
4. `pay(orderId)`:
   - `UnknownOrder()` for an unregistered id, then `AlreadyPaid()` if it was paid before;
   - computes `weiDue` exactly as `quote` does (same reverts);
   - `InsufficientPayment(msg.value, weiDue)` if `msg.value < weiDue`;
   - marks the order paid, records `payer = msg.sender`, adds `weiDue` to `proceeds`;
   - sends `msg.value - weiDue` back to `msg.sender` when it is non-zero, reverting with
     `TransferFailed()` if the payer does not accept it. No call is made when the refund
     is zero.
   The order must be marked paid before the refund is sent: a payer that re-enters `pay`
   for the same order from its refund must hit `AlreadyPaid()`.
5. `withdraw()` is merchant-only (`NotMerchant()`). It sets `proceeds` to zero and sends
   the previous value to the merchant (`TransferFailed()` on failure).
6. The gateway never holds more ETH than `proceeds` after a call returns.

## What the tests check

- Quotes for several prices and feed decimals, including upward rounding.
- Exact payment, overpayment with refund, underpayment, double payment.
- Feed validation on both `quote` and `pay`.
- A payer contract that rejects refunds, and one that re-enters `pay`.
- Merchant withdrawal and access control.
