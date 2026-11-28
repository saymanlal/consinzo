# Minimal ERC-721: Ownership, Approval and Transfer

## Problem Statement

Implement `MinimalNFT` in `src/MinimalNFT.sol`: the core bookkeeping of an ERC-721 token. Each
`tokenId` has exactly one owner, an owner may approve one address per token, and the owner or
the approved address may transfer it.

Operator approvals (`setApprovalForAll`), safe transfers and metadata are out of scope.

## Required Interface

```solidity
function minter() external view returns (address);                   // the deployer
function ownerOf(uint256 tokenId) external view returns (address);
function balanceOf(address owner) external view returns (uint256);
function getApproved(uint256 tokenId) external view returns (address);

function mint(address to, uint256 tokenId) external;
function approve(address approved, uint256 tokenId) external;
function transferFrom(address from, address to, uint256 tokenId) external;

event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

error NotMinter();
error ZeroAddress();
error AlreadyMinted();
error NonexistentToken();
error NotAuthorized();
error WrongOwner();
```

## Rules

1. `mint(to, tokenId)`: `NotMinter()` unless called by the deployer; `ZeroAddress()` if
   `to == address(0)`; `AlreadyMinted()` if the token exists. Otherwise assign the token to
   `to`, increase `to`'s balance and emit `Transfer(address(0), to, tokenId)`. Any `tokenId`,
   including `0`, may be minted.
2. `ownerOf(tokenId)` returns the owner and reverts with `NonexistentToken()` if the token has
   not been minted.
3. `balanceOf(owner)` returns how many tokens `owner` holds and reverts with `ZeroAddress()`
   for `owner == address(0)`.
4. `approve(approved, tokenId)`: `NonexistentToken()` if the token does not exist;
   `NotAuthorized()` unless the caller is the token's current owner. Otherwise store
   `approved` as the token's approved address and emit `Approval(owner, approved, tokenId)`.
   Approving `address(0)` clears the approval.
5. `getApproved(tokenId)` returns the approved address (or `address(0)`) and reverts with
   `NonexistentToken()` if the token does not exist.
6. `transferFrom(from, to, tokenId)` checks, in this order:
   - `NonexistentToken()` if the token does not exist;
   - `WrongOwner()` if `from` is not the current owner;
   - `ZeroAddress()` if `to == address(0)`;
   - `NotAuthorized()` unless the caller is the owner or the token's approved address.

   It then clears the token's approval, updates both balances and the owner, and emits
   `Transfer(from, to, tokenId)`.

## What the Tests Check

Public tests cover minting, an owner transfer and an approved transfer. Hidden tests cover every
revert condition, approval clearing on transfer, stale approvals after a round trip, balances
across several tokens and token id `0`.
