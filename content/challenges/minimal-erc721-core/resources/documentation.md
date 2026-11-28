# ERC-721 Core Concepts

## Non-fungible tokens

In ERC-20 every unit is interchangeable and the ledger maps address to amount. In ERC-721 each
token has a unique `uint256` id and the primary ledger maps id to owner. `balanceOf` is a
secondary counter kept in sync so that wallets can show how many tokens an address holds.

## Functions from EIP-721 used in this challenge

- `ownerOf(tokenId)`: must throw for tokens that are not assigned to a non-zero owner.
- `balanceOf(owner)`: must throw for the zero address.
- `approve(approved, tokenId)` / `getApproved(tokenId)`: one approved address per token; the
  zero address means no approval.
- `transferFrom(from, to, tokenId)`: throws unless the caller is the owner or approved, unless
  `from` is the current owner, and if `to` is the zero address.

The standard also defines operators (`setApprovalForAll`) and `safeTransferFrom`, which are not
part of this exercise.

## Events

`Transfer(from, to, tokenId)` is emitted for mints (`from == address(0)`) and transfers.
`Approval(owner, approved, tokenId)` is emitted when an approval is set. The standard notes that
a transfer implicitly resets the approval to none; emitting an extra `Approval` event for the
reset is not required.
