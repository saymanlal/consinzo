# Check the Result of an ETH Send

`PayoutBox` holds ETH for its users. `deposit()` credits the caller and `withdraw()` pays
the caller's full balance back.

`withdraw()` sets the balance to zero and then calls `send`, which returns `false` on
failure instead of reverting. The return value is ignored. When the send fails (the
receiver is a contract that rejects ETH, or one whose `receive` needs more than the 2300
gas that `send` forwards) the balance is already zero and the ETH is stuck in the box
forever.

## Your task

Patch `starter/src/PayoutBox.sol` so that a failed payment reverts the whole withdrawal.

## Required interface (unchanged)

```solidity
error ZeroDeposit();
error NothingToWithdraw();
error TransferFailed();

function balances(address account) external view returns (uint256);
function deposit() external payable;
function withdraw() external;
```

## Rules

- `withdraw()` sends the caller's whole balance and sets it to zero.
- If the ETH transfer fails, `withdraw()` reverts with `TransferFailed()` and the caller's
  balance is unchanged, so they can try again later.
- The transfer must forward all remaining gas (use `call`, not `send` or `transfer`).
  Contract wallets whose `receive` function writes to storage must be able to withdraw.
- Keep the state update before the external call. A receiver that re-enters `withdraw()`
  must not be paid twice.
- `deposit()` reverts with `ZeroDeposit()` for zero value; `withdraw()` reverts with
  `NothingToWithdraw()` for a zero balance.

## What the tests check

- Deposits and withdrawals for a plain account.
- A receiver that rejects ETH: the withdrawal reverts, the balance is kept, and a later
  withdrawal succeeds once the receiver accepts ETH.
- A receiver that needs more than 2300 gas, and a receiver that re-enters.
