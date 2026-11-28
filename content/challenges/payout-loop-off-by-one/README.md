# Fix an Off-by-One in a Payout Loop

`BatchPayout` lets its owner queue payees with `addPayee`, fund the contract with a plain
ETH transfer and then pay everyone with `payAll()`. After a successful run the queue is
cleared so the next round starts empty.

The loop in `payAll()` uses the bound `i < payees.length - 1`. The last payee in the queue
is skipped, and because the queue is cleared afterwards their payment is lost for good.
With a single payee nobody is paid at all.

## Your task

Patch `starter/src/BatchPayout.sol` so that `payAll()` pays every queued payee exactly
once.

## Required interface (unchanged)

```solidity
error NotOwner();
error ZeroAddress();
error ZeroAmount();
error NoPayees();
error InsufficientFunds();
error TransferFailed();

function owner() external view returns (address);
function totalOwed() external view returns (uint256);
function payeeCount() external view returns (uint256);
function payees(uint256 index) external view returns (address account, uint256 amount);

function addPayee(address account, uint256 amount) external; // owner only
function payAll() external;                                  // owner only
receive() external payable;
```

## Rules

- `payAll()` sends each queued entry its `amount`, in queue order, then clears the queue
  and sets `totalOwed` to zero.
- An address queued twice is paid both amounts.
- `payAll()` reverts with `NoPayees()` when the queue is empty, `InsufficientFunds()` when
  the contract balance is below `totalOwed`, and `TransferFailed()` if any payment fails
  (the whole batch is rolled back).
- ETH above `totalOwed` stays in the contract.
- `addPayee` and `payAll` revert with `NotOwner()` for other callers.

## What the tests check

- Batches of one, three and more payees: everyone receives the exact amount.
- The contract balance drops by exactly `totalOwed`.
- The queue is empty afterwards and a second round works.
- The revert conditions listed above.
