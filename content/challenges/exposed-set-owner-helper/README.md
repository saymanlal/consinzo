# Hide a Public Ownership Helper

`FeeConfig` stores a protocol fee in basis points. Only the `owner` may change the fee or
hand ownership to someone else.

`transferOwnership` checks the caller and then calls the helper `_setOwner`. The helper
was meant to be internal, but it is declared `public`. Anyone can call `_setOwner`
directly, skip the check and take over the contract.

## Your task

Patch `starter/src/FeeConfig.sol` so that ownership can only change through
`transferOwnership`.

## Required interface

```solidity
error NotOwner();
error ZeroAddress();
error FeeTooHigh();

uint256 public constant MAX_FEE_BPS = 1_000;

function owner() external view returns (address);
function feeBps() external view returns (uint256);

function setFee(uint256 newFeeBps) external;          // owner only
function transferOwnership(address newOwner) external; // owner only
```

## Rules

- An account that is not the owner must have no way to change `owner`. A direct external
  call to `_setOwner(address)` from a non-owner must fail and leave `owner` unchanged.
- `transferOwnership` reverts with `NotOwner()` for other callers and with `ZeroAddress()`
  for the zero address. After it succeeds, the new owner has the owner's rights and the
  old owner has none.
- `setFee` reverts with `NotOwner()` for other callers and with `FeeTooHigh()` above
  `MAX_FEE_BPS`.

## What the tests check

- The owner can set the fee and transfer ownership.
- A stranger calling `_setOwner(address)` through a low-level call does not become owner
  and cannot change the fee afterwards.
- The revert conditions listed above.
