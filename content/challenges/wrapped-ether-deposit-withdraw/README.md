# Wrapped Ether: 1:1 Deposit and Withdraw

## Problem Statement

Ether is not an ERC-20 token, so protocols wrap it. Implement `WrappedEther` in
`src/WrappedEther.sol`: every wei deposited credits one unit of balance, and every unit
withdrawn returns one wei.

## Required Interface

```solidity
function name() external view returns (string memory);     // "Wrapped Ether"
function symbol() external view returns (string memory);   // "WETH"
function decimals() external view returns (uint8);         // 18
function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);

receive() external payable;
function deposit() external payable;
function withdraw(uint256 amount) external;
function transfer(address to, uint256 amount) external returns (bool);

event Deposit(address indexed account, uint256 amount);
event Withdrawal(address indexed account, uint256 amount);
event Transfer(address indexed from, address indexed to, uint256 value);

error ZeroAddress();
error InsufficientBalance();
error EthTransferFailed();
```

## Rules

1. `deposit()` adds `msg.value` to `balanceOf[msg.sender]` and to `totalSupply`, and emits
   `Deposit(msg.sender, msg.value)`. A zero-value deposit is allowed.
2. Sending Ether to the contract with empty calldata (`receive`) behaves exactly like `deposit()`.
3. `withdraw(amount)` reverts with `InsufficientBalance()` if the caller holds less than
   `amount`. Otherwise it reduces the caller's balance and `totalSupply` by `amount`, sends
   `amount` wei to the caller and emits `Withdrawal(msg.sender, amount)`. If the Ether
   transfer fails, revert with `EthTransferFailed()`.
4. `transfer(to, amount)` reverts with `ZeroAddress()` if `to == address(0)` and with
   `InsufficientBalance()` if the caller holds less than `amount`. Otherwise it moves the
   balance, emits `Transfer(msg.sender, to, amount)` and returns `true`.
5. `totalSupply` must always equal the sum of all balances, and the contract must always hold
   at least `totalSupply` wei. A caller must never be able to withdraw more than its balance,
   even if it re-enters `withdraw` while receiving Ether.

Allowances (`approve` / `transferFrom`) are out of scope.

## What the Tests Check

Public tests cover deposit, the `receive` path, withdraw and transfer. Hidden tests cover the
revert conditions above, recipients that reject Ether, a re-entering withdrawer, and that
`totalSupply` tracks the contract's Ether across mixed sequences.
