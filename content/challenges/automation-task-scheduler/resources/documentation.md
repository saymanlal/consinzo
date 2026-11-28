# Background: Automation-Compatible Contracts

## The two-function interface

Keeper networks agree on a small interface:

```solidity
function checkUpkeep(bytes calldata checkData)
    external returns (bool upkeepNeeded, bytes memory performData);
function performUpkeep(bytes calldata performData) external;
```

Nodes call `checkUpkeep` off-chain with `eth_call` on every block. When it returns `true`
one of them submits `performUpkeep(performData)`. `checkData` is a constant chosen when
the upkeep is registered; it is commonly used to split one contract's work into ranges.

## Why re-validation is mandatory

- Time passes between the simulation and the transaction; state may have changed.
- `performUpkeep` is an ordinary external function. Unless it is restricted, anyone can
  call it with arbitrary bytes.

`performUpkeep` therefore repeats every check that matters. A useful structure is one
predicate (`isDue`) that both functions call.

## Working with `bytes` payloads

`abi.encode(ids)` with `uint256[] memory ids` produces bytes that
`abi.decode(data, (uint256[]))` turns back into the array. Memory arrays have a fixed
length, so a variable number of results is usually collected in an over-sized buffer and
copied.

## Low-level calls

`(bool success, bytes memory ret) = target.call(data);` does not revert when the callee
reverts; it returns `false`. This is how a scheduler isolates one task's failure from the
rest of the batch. State that guards against repeated execution must be written before the
call (checks-effects-interactions).

## Fixed schedules

To keep a task on the grid `start + k * interval` after delays, advance by whole
intervals: compute how many full intervals have elapsed since the scheduled time and add
one more.
