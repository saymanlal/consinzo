# Fixed-Supply Token Ledger

## Problem Statement

Implement `FixedSupplyLedger` in `src/FixedSupplyLedger.sol`: the smallest useful token. The
whole supply is created once, in the constructor, and assigned to the deployer. After that the
supply never changes; holders can only move balances with `transfer`.

## Required Interface

```solidity
constructor(string memory name_, string memory symbol_, uint256 initialSupply);

function name() external view returns (string memory);
function symbol() external view returns (string memory);
function decimals() external view returns (uint8);          // 18
function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);
function transfer(address to, uint256 amount) external returns (bool);

event Transfer(address indexed from, address indexed to, uint256 value);

error ZeroAddress();
error InsufficientBalance();
```

## Rules

1. The constructor stores `name_` and `symbol_`, sets `totalSupply = initialSupply`, credits
   the full amount to `msg.sender` and emits `Transfer(address(0), msg.sender, initialSupply)`.
2. `transfer(to, amount)`:
   - reverts with `ZeroAddress()` if `to == address(0)`;
   - reverts with `InsufficientBalance()` if the caller's balance is below `amount`;
   - otherwise moves `amount` from the caller to `to`, emits
     `Transfer(msg.sender, to, amount)` and returns `true`.
3. Transfers of `0` and transfers to yourself are valid and must leave every balance correct.
4. `totalSupply` never changes after construction and always equals the sum of all balances.

There is no minting, burning or allowance mechanism.

## What the Tests Check

Public tests cover the constructor mint, metadata and a basic transfer. Hidden tests cover both
revert conditions, boundary amounts, self-transfers, zero-amount transfers, deployment by a
different account and conservation of supply over a chain of transfers.
