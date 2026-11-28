# Dead-Man Switch Inheritance Wallet

## Problem Statement

Implement `DeadManSwitch` in `src/DeadManSwitch.sol`: a wallet that passes to an heir when its
owner stops showing signs of life.

The owner proves they are still in control by calling `heartbeat()` (or any other owner-only
function). If `silencePeriod` seconds pass without any owner activity, the `heir` may call
`claim()` and becomes the new owner.

## Required Interface

```solidity
constructor(address _heir, uint256 _silencePeriod) payable   // already implemented
receive() external payable                                    // already implemented

function heartbeat() external
function setHeir(address newHeir) external
function withdraw(uint256 amount) external
function claim() external
function claimableAt() external view returns (uint256)

// public state (already declared in the starter)
address public owner;
address public heir;
uint256 public immutable silencePeriod;
uint256 public lastHeartbeat;
```

## Rules

1. `heartbeat()`, `setHeir()` and `withdraw()` revert with `NotOwner()` unless
   `msg.sender == owner`. Each of them, when it succeeds, sets `lastHeartbeat = block.timestamp`.
2. `heartbeat()` emits `Heartbeat(block.timestamp)`.
3. `setHeir(newHeir)` reverts with `InvalidHeir()` if `newHeir` is `address(0)` or the owner
   itself; otherwise it stores the new heir and emits `HeirChanged(newHeir)`.
4. `withdraw(amount)` sends `amount` wei to the owner. It reverts with `TransferFailed()` if the
   contract holds less than `amount` or the transfer fails.
5. `claimableAt()` returns `lastHeartbeat + silencePeriod`.
6. `claim()`
   - reverts with `NotHeir()` unless `msg.sender == heir`;
   - reverts with `OwnerStillActive()` while `block.timestamp < claimableAt()`;
   - otherwise makes the caller the new `owner`, sets `heir` to `address(0)`, sets
     `lastHeartbeat = block.timestamp` and emits `Inherited(previousOwner, newOwner)`.
7. The ETH stays in the contract when ownership changes. The new owner uses `withdraw` and can
   name their own heir with `setHeir`.

## What the Tests Check

- Public tests: heartbeats move the claim time, the heir takes over after a full silent period, and
  the new owner can withdraw.
- Hidden tests: the exact boundary second, access control on every function, heir replacement,
  the previous owner losing all rights, the cleared heir after a claim, and withdrawal limits.
