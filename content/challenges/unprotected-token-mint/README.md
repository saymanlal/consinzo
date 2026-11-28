# Restrict an Unprotected Token Mint

`RewardToken` is a minimal token used to pay out loyalty rewards. The deployer is the
`owner` and is supposed to be the only account that can create new tokens.

The contract works, but `mint` has no access control: any address can mint any amount
to itself and dilute every holder.

## Your task

Patch `starter/src/RewardToken.sol` so that only the current owner can mint.

## Required interface (unchanged)

```solidity
error NotOwner();
error ZeroAddress();
error InsufficientBalance();

function owner() external view returns (address);
function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);

function mint(address to, uint256 amount) external;
function transfer(address to, uint256 amount) external returns (bool);
function transferOwnership(address newOwner) external;
```

## Rules

- `mint` reverts with `NotOwner()` unless `msg.sender == owner`.
- `mint` still reverts with `ZeroAddress()` when `to` is the zero address, and still
  increases both `balanceOf(to)` and `totalSupply` by `amount`.
- `transferOwnership` already reverts with `NotOwner()` for other callers. After a
  handover the new owner can mint and the previous owner cannot.
- `transfer` is not privileged and must keep working for every holder.

## What the tests check

- The owner can mint and holders can transfer.
- A stranger calling `mint` reverts with `NotOwner()` and the supply does not change.
- Minting rights follow ownership after `transferOwnership`.
