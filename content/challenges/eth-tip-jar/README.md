# ETH Tip Jar With Receive and Owner Withdrawal

## Problem Statement

Implement `TipJar` in `src/TipJar.sol`. Anyone can send ETH to the jar. The jar records how much
each address has tipped in total. The deployer is the owner and is the only account that can take
the money out.

## Required Interface

```solidity
error NotOwner(address caller);
error ZeroTip();
error NothingToWithdraw();
error TransferFailed();

event Tipped(address indexed tipper, uint256 amount);
event Withdrawn(address indexed owner, uint256 amount);

function owner() external view returns (address);
function totalTips() external view returns (uint256);
function tipperCount() external view returns (uint256);
function tipsOf(address tipper) external view returns (uint256);

receive() external payable;
function tip() external payable;
function withdraw() external;
```

## Rules

1. `owner` is the deployer and never changes.
2. `tip()` and a plain ETH transfer (handled by `receive()`) behave identically:
   - revert with `ZeroTip()` when `msg.value == 0`;
   - add `msg.value` to `tipsOf[msg.sender]` and to `totalTips`;
   - increase `tipperCount` by one the first time an address tips;
   - emit `Tipped(msg.sender, msg.value)`.
3. `totalTips`, `tipsOf` and `tipperCount` are lifetime statistics. Withdrawals do not reduce them.
4. `withdraw()`:
   - reverts with `NotOwner(msg.sender)` for any other caller;
   - reverts with `NothingToWithdraw()` when the contract balance is zero;
   - sends the entire contract balance to the owner, reverting with `TransferFailed()` if the
     transfer does not succeed;
   - emits `Withdrawn(owner, amount)`.

## What the Tests Check

- Tips through `tip()` and through a plain transfer are both recorded.
- Per-tipper totals, the lifetime total and the distinct tipper count.
- Only the owner can withdraw; the owner receives the whole balance; an empty jar cannot be
  withdrawn.
- Statistics survive a withdrawal and tipping continues afterwards.
