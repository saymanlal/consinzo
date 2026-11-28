# Capped Mintable ERC-20

## Problem Statement

Implement `CappedToken` in `src/CappedToken.sol`. The deployer is the owner and may mint
tokens, but `totalSupply` must never exceed the `cap` fixed at deployment.

## Required Interface

```solidity
constructor(uint256 cap_);

function owner() external view returns (address);
function cap() external view returns (uint256);
function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);
function remainingMintable() external view returns (uint256);

function mint(address to, uint256 amount) external;
function burn(uint256 amount) external;
function transfer(address to, uint256 amount) external returns (bool);

event Transfer(address indexed from, address indexed to, uint256 value);

error ZeroCap();
error NotOwner();
error ZeroAddress();
error CapExceeded();
error InsufficientBalance();
```

## Rules

1. The constructor reverts with `ZeroCap()` if `cap_ == 0`. Otherwise it stores the cap (it can
   never change) and sets `owner = msg.sender`. No tokens are minted at deployment.
2. `mint(to, amount)` checks, in this order:
   - `NotOwner()` if the caller is not the owner;
   - `ZeroAddress()` if `to == address(0)`;
   - `CapExceeded()` if minting `amount` would make `totalSupply` greater than `cap`.

   It then increases `totalSupply` and `balanceOf[to]` and emits
   `Transfer(address(0), to, amount)`. The cap check must revert with `CapExceeded()` for
   **every** `amount` that does not fit, including values close to `type(uint256).max`; an
   arithmetic panic is not acceptable.
3. `burn(amount)` reverts with `InsufficientBalance()` if the caller holds less than `amount`;
   otherwise it reduces the caller's balance and `totalSupply` and emits
   `Transfer(msg.sender, address(0), amount)`. Burned supply can be minted again later.
4. `transfer(to, amount)` reverts with `ZeroAddress()` for the zero recipient and
   `InsufficientBalance()` if the caller holds less than `amount`; otherwise it moves the tokens,
   emits `Transfer` and returns `true`.
5. `remainingMintable()` returns `cap - totalSupply`.

## What the Tests Check

Public tests cover minting under the cap, the revert when the cap is exceeded and
`remainingMintable`. Hidden tests cover minting exactly to the cap, overflow-sized mint amounts,
access control, interaction between burning and the cap, and the constructor check.
