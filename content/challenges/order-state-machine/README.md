# Order Lifecycle State Machine

## Problem Statement

Implement `OrderTracker` in `src/OrderTracker.sol`. The deployer is the seller. Any account can
create an order and becomes its buyer. An order then moves through a fixed sequence of states:

```
Created --pay (buyer)--> Paid --ship (seller)--> Shipped --confirmDelivery (buyer)--> Delivered
```

No payment is handled; this challenge is about the state machine only.

## Required Interface

```solidity
enum Status { None, Created, Paid, Shipped, Delivered }

error OrderNotFound(uint256 id);
error NotBuyer(address caller);
error NotSeller(address caller);
error InvalidState(Status current);

event OrderCreated(uint256 indexed id, address indexed buyer);
event StatusChanged(uint256 indexed id, Status status);

function seller() external view returns (address);
function orderCount() external view returns (uint256);
function createOrder() external returns (uint256 id);
function pay(uint256 id) external;
function ship(uint256 id) external;
function confirmDelivery(uint256 id) external;
function statusOf(uint256 id) external view returns (Status);
function buyerOf(uint256 id) external view returns (address);
```

## Rules

1. `seller` is the deployer and never changes.
2. `createOrder()` assigns the next id, starting at `1` and increasing by one per order, records
   `msg.sender` as the buyer, sets the status to `Created`, increases `orderCount`, emits
   `OrderCreated(id, buyer)` and returns the id.
3. Each transition performs its checks in this order:
   1. the order exists, otherwise `OrderNotFound(id)`;
   2. the caller is the required party, otherwise `NotBuyer(msg.sender)` or `NotSeller(msg.sender)`;
   3. the order is in the required state, otherwise `InvalidState(currentStatus)`.
4. Transitions and parties:
   - `pay`: buyer of that order, `Created` to `Paid`;
   - `ship`: seller, `Paid` to `Shipped`;
   - `confirmDelivery`: buyer of that order, `Shipped` to `Delivered`.
5. Each successful transition emits `StatusChanged(id, newStatus)`.
6. `Delivered` is final. States can never be skipped or revisited.
7. `statusOf(id)` returns `Status.None` and `buyerOf(id)` returns `address(0)` for an id that was
   never created. Neither reverts.

## What the Tests Check

- The full happy path and the ids handed out.
- Skipped, repeated and out-of-order transitions revert with `InvalidState` carrying the current
  status.
- Wrong callers revert with `NotBuyer` / `NotSeller`; unknown ids revert with `OrderNotFound`.
- Several orders progress independently.
