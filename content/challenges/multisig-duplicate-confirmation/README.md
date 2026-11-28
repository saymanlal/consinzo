# Count Each Multisig Owner Only Once

`ConfirmationWallet` holds ETH for a group of owners. Any owner can submit a transaction,
owners confirm it, and once `threshold` owners have confirmed, any owner can execute it.

## The bugs

1. `confirm` adds one to the transaction's counter on every call. The same owner can call it
   `threshold` times and then execute alone.
2. The constructor does not validate the owner list. A duplicated address is counted as two
   owners, so the stated threshold can be reached by fewer distinct keys than intended. The
   zero address and nonsensical thresholds are accepted as well.

## Your task

Patch `src/ConfirmationWallet.sol` so the threshold always means "this many distinct
owners". Keep the interface unchanged.

```solidity
constructor(address[] memory owners_, uint256 threshold_);
function submit(address to, uint256 value, bytes calldata data) external returns (uint256 txId);
function confirm(uint256 txId) external;
function revoke(uint256 txId) external;
function execute(uint256 txId) external;
function confirmationCount(uint256 txId) external view returns (uint256);
function confirmed(uint256 txId, address owner) external view returns (bool);
function isOwner(address account) external view returns (bool);
function ownerCount() external view returns (uint256);
function threshold() external view returns (uint256);
```

### Rules

- Constructor: reverts with `InvalidOwner()` for the zero address, `DuplicateOwner()` for a
  repeated address, and `InvalidThreshold()` unless `1 <= threshold_ <= owners_.length`.
- `submit`, `confirm`, `revoke` and `execute` are owner-only (`NotOwner()`). `submit` does
  not confirm on behalf of the submitter.
- `confirm`: unknown id reverts with `TxNotFound()`, an executed transaction with
  `AlreadyExecuted()`, and a second confirmation by the same owner with `AlreadyConfirmed()`.
- `revoke`: removes the caller's own confirmation; reverts with `NotConfirmed()` if there is
  none, and with `AlreadyExecuted()` after execution.
- `execute`: reverts with `BelowThreshold()` if fewer than `threshold` distinct owners
  currently confirm, with `AlreadyExecuted()` on a second call, and with `CallFailed()` if
  the target call fails (the transaction then stays unexecuted).
- `confirmationCount(txId)` is the number of distinct owners currently confirming.

## What the tests check

- A single owner confirming repeatedly cannot execute a 2-of-3 transaction.
- Two distinct owners can; revoking drops the count again.
- Constructor validation, access control and every revert listed above.
