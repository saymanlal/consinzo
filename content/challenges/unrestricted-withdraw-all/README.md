# Lock Down an Open withdrawAll

`TipJar` accepts ETH tips through `tip()` and through plain transfers. The `owner`, fixed
at deployment, is meant to collect them with `withdrawAll()`.

The contract works, but `withdrawAll()` never checks the caller. The first person to
notice can take every tip.

## Your task

Patch `starter/src/TipJar.sol` so that only the owner can withdraw.

## Required interface (unchanged)

```solidity
error NotOwner();
error ZeroTip();
error NothingToWithdraw();
error TransferFailed();

constructor(address owner_);

function owner() external view returns (address);
function totalTips() external view returns (uint256);
function tipsFrom(address tipper) external view returns (uint256);

function tip() external payable;
receive() external payable;      // counts as a tip
function withdrawAll() external;
```

## Rules

- `withdrawAll()` reverts with `NotOwner()` unless `msg.sender == owner`. The owner check
  comes first, so a stranger gets `NotOwner()` even when the jar is empty.
- For the owner it sends the entire contract balance to the owner, reverts with
  `NothingToWithdraw()` when the balance is zero and with `TransferFailed()` if the ETH
  transfer fails.
- Tipping is open to everyone and its bookkeeping (`totalTips`, `tipsFrom`) is unchanged.

## What the tests check

- Tips are recorded, and the owner receives the full balance.
- A stranger (an EOA or a contract) cannot withdraw, and the jar keeps its balance.
- The error cases above.
