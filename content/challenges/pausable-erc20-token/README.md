# Pausable ERC-20 Token

## Problem Statement

Implement `PausableToken` in `src/PausableToken.sol`: an ERC-20 token whose owner can halt
token movement during an incident and resume it afterwards. The exercise is about deciding, per
function, what the pause does and does not block.

## Required Interface

```solidity
function owner() external view returns (address);          // the deployer
function paused() external view returns (bool);            // false after deployment
function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);
function allowance(address owner, address spender) external view returns (uint256);

function pause() external;
function unpause() external;
function mint(address to, uint256 amount) external;
function burn(uint256 amount) external;
function transfer(address to, uint256 amount) external returns (bool);
function approve(address spender, uint256 amount) external returns (bool);
function transferFrom(address from, address to, uint256 amount) external returns (bool);

event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);
event Paused(address account);
event Unpaused(address account);

error NotOwner();
error EnforcedPause();
error ExpectedPause();
error ZeroAddress();
error InsufficientBalance();
error InsufficientAllowance();
```

## Pause Rules

| Function | While paused |
| --- | --- |
| `transfer`, `transferFrom` | revert with `EnforcedPause()` |
| `burn` | reverts with `EnforcedPause()` |
| `mint` | **allowed** (owner only, as always) |
| `approve` | **allowed** |
| view functions | allowed |

- `pause()`: `NotOwner()` if the caller is not the owner; `EnforcedPause()` if already paused;
  otherwise set `paused = true` and emit `Paused(msg.sender)`.
- `unpause()`: `NotOwner()` if the caller is not the owner; `ExpectedPause()` if not paused;
  otherwise set `paused = false` and emit `Unpaused(msg.sender)`.
- In blocked functions the pause check comes first, before any other validation.

## Token Rules

- `mint(to, amount)`: `NotOwner()` for other callers, `ZeroAddress()` for `to == address(0)`;
  increases `totalSupply` and the balance; emits `Transfer(address(0), to, amount)`.
- `burn(amount)`: `InsufficientBalance()` if the caller holds less; reduces balance and
  `totalSupply`; emits `Transfer(msg.sender, address(0), amount)`.
- `transfer(to, amount)`: `ZeroAddress()` for the zero recipient, `InsufficientBalance()` if the
  caller holds less; returns `true`.
- `approve(spender, amount)`: `ZeroAddress()` for the zero spender; overwrites the allowance;
  returns `true`.
- `transferFrom(from, to, amount)`: `InsufficientAllowance()` if
  `allowance[from][msg.sender] < amount`; an allowance of `type(uint256).max` is not decremented,
  any other is reduced by `amount`; then the same checks and effects as `transfer`, from `from`.

## What the Tests Check

Public tests cover normal operation, that transfers revert while paused and that unpausing
restores them. Hidden tests check every row of the pause table, the pause state machine, access
control and that a blocked call changes nothing.
