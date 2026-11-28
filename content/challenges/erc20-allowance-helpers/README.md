# ERC-20 Allowance Helpers and Infinite Approvals

## Problem Statement

`approve` overwrites an allowance. If a holder changes an allowance from 100 to 50, the spender
can front-run the change, spend the old 100 and then spend the new 50. Relative adjustments
avoid that race. Implement `AllowanceToken` in `src/AllowanceToken.sol` with
`increaseAllowance`, `decreaseAllowance` and a `transferFrom` that handles infinite approvals.

## Required Interface

```solidity
constructor(uint256 initialSupply);   // minted to the deployer

function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);
function allowance(address owner, address spender) external view returns (uint256);

function transfer(address to, uint256 amount) external returns (bool);
function approve(address spender, uint256 amount) external returns (bool);
function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
function transferFrom(address from, address to, uint256 amount) external returns (bool);

event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);

error ZeroAddress();
error InsufficientBalance();
error InsufficientAllowance();
error AllowanceOverflow();
error AllowanceUnderflow();
```

## Rules

1. `transfer(to, amount)`: `ZeroAddress()` for the zero recipient; `InsufficientBalance()` if
   the caller holds less than `amount`; otherwise move tokens, emit `Transfer`, return `true`.
2. `approve(spender, amount)`: `ZeroAddress()` for the zero spender; otherwise overwrite
   `allowance[msg.sender][spender]`, emit `Approval(msg.sender, spender, amount)`, return `true`.
3. `increaseAllowance(spender, addedValue)`: `ZeroAddress()` for the zero spender;
   `AllowanceOverflow()` if `current + addedValue` would exceed `type(uint256).max`; otherwise
   set the allowance to the sum, emit `Approval` with the **new total**, return `true`.
4. `decreaseAllowance(spender, subtractedValue)`: `ZeroAddress()` for the zero spender;
   `AllowanceUnderflow()` if `subtractedValue > current`; otherwise set the allowance to the
   difference, emit `Approval` with the **new total**, return `true`.
5. `transferFrom(from, to, amount)`:
   - `InsufficientAllowance()` if `allowance[from][msg.sender] < amount` (checked first);
   - if the allowance is exactly `type(uint256).max` it is infinite and is not changed;
     otherwise it is reduced by `amount`;
   - then the same recipient and balance checks and effects as `transfer`, from `from`;
   - the caller needs an allowance even when `from == msg.sender`.
6. The helpers have no special case for infinite allowances: they are plain arithmetic on the
   stored number. Decreasing a maximal allowance by 1 leaves `type(uint256).max - 1`, which is
   finite from then on.

## What the Tests Check

Public tests cover the two helpers and a `transferFrom` that consumes allowance. Hidden tests
cover overflow and underflow boundaries, the infinite-approval rule and its interaction with the
helpers, spender isolation and the zero-address checks.
