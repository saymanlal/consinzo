# Token Ledger Background

## What a fungible token is

An ERC-20 style token is a mapping from address to balance plus a total. No coins move
anywhere: a transfer is a subtraction in one storage slot and an addition in another, inside one
transaction, so either both happen or neither does.

## The parts of EIP-20 used here

- `totalSupply()`, `balanceOf(address)` and `transfer(address,uint256) returns (bool)`.
- `event Transfer(address indexed from, address indexed to, uint256 value)`, which must be
  emitted on every transfer, including transfers of zero. Creating tokens should emit it with
  `from == address(0)`.
- `name`, `symbol` and `decimals` are optional metadata. `decimals` only affects display:
  balances are always integers of the smallest unit.

## Custom errors

`error InsufficientBalance();` declares an error; `revert InsufficientBalance();` aborts the
call with a 4-byte selector as return data. They are cheaper than revert strings and can be
matched exactly by callers and tests.

## Checked arithmetic

Since Solidity 0.8, `+`, `-` and `*` revert on overflow or underflow. Inside an `unchecked`
block they wrap instead, which is only safe when a preceding check proves the operation cannot
overflow.
