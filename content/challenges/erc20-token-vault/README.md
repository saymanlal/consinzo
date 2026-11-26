# Implement a Production ERC-20 Token Contract

## Problem Statement

Implement `ConsinzoToken` in `src/ConsinzoToken.sol` conforming to the EIP-20 standard.

## Technical Requirements

1. Store `name`, `symbol`, `decimals` (18), `totalSupply`, `balanceOf`, and `allowance`.
2. Assign an `owner` in the constructor and allow only `owner` to call `mint(address to, uint256 amount)`.
3. Implement `transfer(address to, uint256 amount)` returning `bool`:
   - Revert if `to == address(0)` or `balanceOf[msg.sender] < amount`.
   - Emit `Transfer(msg.sender, to, amount)`.
4. Implement `approve(address spender, uint256 amount)` returning `bool`:
   - Revert if `spender == address(0)`.
   - Emit `Approval(msg.sender, spender, amount)`.
5. Implement `transferFrom(address from, address to, uint256 amount)` returning `bool`:
   - Check allowance; preserve `type(uint256).max` infinite allowances without decrementing.
   - Check balance and `to != address(0)`.
   - Emit `Transfer(from, to, amount)`.
6. Implement `burn(uint256 amount)` so callers can burn their own tokens, reducing `totalSupply`.
