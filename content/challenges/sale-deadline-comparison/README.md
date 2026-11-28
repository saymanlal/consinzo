# Fix the Deadline Checks of a Timed Sale

`TimedSale` sells units at a fixed ETH price until a deadline. After the deadline the
owner calls `finalize()` to collect the proceeds.

Both time checks are wrong:

- `buy` rejects purchases only when `block.timestamp == deadline`. One second later the
  sale is open again and never closes.
- `finalize` requires `block.timestamp > deadline`, so it is refused at the deadline
  itself.

Together these let buyers keep purchasing after the owner has finalised, leaving their
ETH stranded in a finished sale.

## Your task

Patch `starter/src/TimedSale.sol` so that the sale is open strictly before the deadline
and closed from the deadline onwards.

## Required interface (unchanged)

```solidity
error NotOwner();
error SaleClosed();
error SaleStillOpen();
error AlreadyFinalized();
error ZeroQuantity();
error WrongPayment();
error TransferFailed();

constructor(uint256 price_, uint256 duration_);

function owner() external view returns (address);
function price() external view returns (uint256);
function deadline() external view returns (uint256);   // deployment time + duration_
function totalSold() external view returns (uint256);
function finalized() external view returns (bool);
function purchased(address buyer) external view returns (uint256);

function buy(uint256 quantity) external payable;
function finalize() external; // owner only
```

## Rules

- `buy` succeeds while `block.timestamp < deadline`. At `block.timestamp >= deadline` it
  reverts with `SaleClosed()`.
- `finalize` reverts with `SaleStillOpen()` while `block.timestamp < deadline` and is
  allowed from `block.timestamp == deadline` onwards.
- `buy` also reverts with `ZeroQuantity()` for a zero quantity and `WrongPayment()` unless
  `msg.value == price * quantity`.
- `finalize` reverts with `NotOwner()` for other callers and `AlreadyFinalized()` on a
  second call. It sends the whole contract balance to the owner.

## What the tests check

- Purchases before the deadline.
- `buy` and `finalize` at `deadline - 1`, `deadline`, `deadline + 1` and much later.
- The remaining revert conditions.
