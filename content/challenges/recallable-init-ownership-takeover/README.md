# Stop a Re-callable init From Stealing Ownership

`SharedWallet` is deployed by a factory that cannot pass constructor arguments, so the
owner is assigned afterwards by calling `init(owner_)`. The owner can then withdraw ETH
held by the wallet.

`init` sets an `initialized` flag but never checks it. Anyone can call `init` again,
make themselves the owner and withdraw everything.

## Your task

Patch `starter/src/SharedWallet.sol` so that `init` succeeds exactly once.

## Required interface (unchanged)

```solidity
error AlreadyInitialized();
error NotOwner();
error ZeroAddress();
error InsufficientBalance();
error TransferFailed();

function owner() external view returns (address);
function initialized() external view returns (bool);

function init(address owner_) external;
function withdraw(address payable to, uint256 amount) external; // owner only
receive() external payable;
```

## Rules

- The first successful `init(owner_)` sets `owner` and `initialized`.
- Every later call to `init` reverts with `AlreadyInitialized()`, whoever the caller is,
  including the current owner.
- `init(address(0))` reverts with `ZeroAddress()` and does not count as initialisation: a
  valid `init` call afterwards must still succeed.
- `withdraw` reverts with `NotOwner()` unless called by the owner (which also means nobody
  can withdraw before initialisation), `ZeroAddress()` for a zero recipient,
  `InsufficientBalance()` when `amount` exceeds the wallet balance and `TransferFailed()`
  when the transfer fails.

## What the tests check

- Normal setup and owner withdrawals.
- A second `init` by an attacker (EOA or contract) reverts and the funds stay put.
- The zero-address and pre-initialisation cases above.
