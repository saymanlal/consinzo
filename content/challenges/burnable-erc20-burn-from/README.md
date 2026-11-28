# Burnable ERC-20 with burnFrom

## Problem Statement

Implement `BurnableToken` in `src/BurnableToken.sol`. The full supply is minted to the deployer.
Holders can destroy their own tokens with `burn`, and an approved spender can destroy a holder's
tokens with `burnFrom`, which consumes allowance the same way `transferFrom` would.

## Required Interface

```solidity
constructor(uint256 initialSupply);

function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);
function allowance(address owner, address spender) external view returns (uint256);

function transfer(address to, uint256 amount) external returns (bool);
function approve(address spender, uint256 amount) external returns (bool);
function burn(uint256 amount) external;
function burnFrom(address account, uint256 amount) external;

event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);

error ZeroAddress();
error InsufficientBalance();
error InsufficientAllowance();
```

## Rules

1. The constructor mints `initialSupply` to `msg.sender` and emits
   `Transfer(address(0), msg.sender, initialSupply)`.
2. `transfer(to, amount)`: `ZeroAddress()` if `to == address(0)`; `InsufficientBalance()` if the
   caller holds less than `amount`; otherwise move the tokens, emit `Transfer`, return `true`.
3. `approve(spender, amount)`: `ZeroAddress()` if `spender == address(0)`; otherwise set
   `allowance[msg.sender][spender] = amount` (overwriting), emit `Approval`, return `true`.
4. `burn(amount)`: `InsufficientBalance()` if the caller holds less than `amount`; otherwise
   reduce the caller's balance and `totalSupply` by `amount` and emit
   `Transfer(msg.sender, address(0), amount)`.
5. `burnFrom(account, amount)`:
   - reads `allowance[account][msg.sender]`. If it is below `amount`, revert with
     `InsufficientAllowance()`. This check comes before the balance check.
   - if the allowance is `type(uint256).max` it is left unchanged; otherwise it is reduced by
     `amount`;
   - then burns exactly as `burn` does, but from `account`: `InsufficientBalance()` if
     `account` holds less than `amount`, and `Transfer(account, address(0), amount)` on success.
   - There is no exemption when `account == msg.sender`: without an allowance to itself the
     caller must use `burn`.
6. Burned tokens are gone: they are not credited to the caller, to `address(0)` or to anyone
   else. `totalSupply` always equals the sum of all balances.

`transferFrom` is out of scope for this exercise.

## What the Tests Check

Public tests cover `burn`, `burnFrom` with allowance consumption and the allowance revert. Hidden
tests cover the order of checks, infinite approvals, the self-`burnFrom` case, boundary amounts
and supply conservation.
