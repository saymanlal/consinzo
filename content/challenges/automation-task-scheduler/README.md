# Automation-Compatible Task Scheduler

## Problem Statement

Keeper networks (for example Chainlink Automation) run contracts on a schedule using two
functions. Off-chain nodes simulate `checkUpkeep`; when it reports work, a node sends a
transaction calling `performUpkeep` with the bytes that `checkUpkeep` returned. The
simulation and the transaction happen at different times and `performUpkeep` is callable
by anyone with any bytes, so it must validate everything again.

Implement `TaskScheduler` in `src/TaskScheduler.sol`: a registry of recurring calls that
exposes this two-function interface. The keeper network is modelled by the tests calling
the two functions directly.

## Interface

```solidity
constructor(uint256 maxBatch_)

function maxBatch() external view returns (uint256);
function taskCount() external view returns (uint256);

function registerTask(address target, bytes calldata data, uint64 interval, uint64 firstRunAt)
    external returns (uint256 id);
function cancelTask(uint256 id) external;

function getTask(uint256 id) external view returns (
    address owner, address target, uint64 interval, uint64 nextRunAt,
    bool active, uint32 runs, uint32 failures
);
function isDue(uint256 id) external view returns (bool);

function checkUpkeep(bytes calldata checkData)
    external view returns (bool upkeepNeeded, bytes memory performData);
function performUpkeep(bytes calldata performData) external;

event TaskRegistered(uint256 indexed id, address indexed owner, address indexed target, uint64 interval, uint64 firstRunAt);
event TaskCancelled(uint256 indexed id);
event TaskPerformed(uint256 indexed id, bool success, uint64 nextRunAt);

error ZeroBatch();
error ZeroAddress();
error ZeroInterval();
error StartInPast();
error NotTaskOwner();
error TaskNotActive();
error BatchTooLarge();
error NothingDue();
```

## Rules

### Registration

1. The constructor reverts with `ZeroBatch()` when `maxBatch_ == 0`.
2. `registerTask` checks, in this order: `target != address(0)` (`ZeroAddress()`),
   `interval != 0` (`ZeroInterval()`), `firstRunAt >= block.timestamp` (`StartInPast()`).
   Ids start at 1 and increase by 1; `taskCount` is the last id handed out. The caller
   becomes the task owner, the task is active, and `nextRunAt = firstRunAt`.
3. `cancelTask` reverts with `NotTaskOwner()` unless the caller is the task owner (this
   also covers ids that do not exist) and with `TaskNotActive()` if the task was already
   cancelled. A cancelled task never runs again.
4. A task is *due* when it exists, is active and `block.timestamp >= nextRunAt`. `isDue`
   returns false for unknown ids.

### checkUpkeep

5. `checkData` selects the id range to scan. Empty `checkData` means every id. Otherwise
   it is `abi.encode(uint256 lo, uint256 hi)`, an inclusive range; `lo == 0` is treated as
   1 and `hi` above `taskCount` is treated as `taskCount`. An empty range is not an error.
6. The function collects the ids of due tasks in the range in ascending order and stops
   after `maxBatch` ids. `performData` is `abi.encode(uint256[] ids)` (an empty array when
   nothing is due) and `upkeepNeeded` is `ids.length > 0`.

### performUpkeep

7. Anyone may call it. `performData` is `abi.encode(uint256[] ids)`. More than `maxBatch`
   ids reverts with `BatchTooLarge()`.
8. Every id is validated again. Ids that are not due at execution time (unknown,
   cancelled, not yet due, or already executed earlier in the same batch) are skipped
   silently. If no id in the batch was due the call reverts with `NothingDue()`.
9. For each due task, **before** calling the target:
   - `runs` increases by 1;
   - `nextRunAt` moves forward by whole intervals to the first slot strictly after
     `block.timestamp`: `nextRunAt += interval * ((block.timestamp - nextRunAt) / interval + 1)`.
     Missed slots are not replayed.
10. The task's stored `data` is then sent to `target` with a low-level call. If the call
    reverts, `failures` increases by 1 and the batch continues; one failing task must not
    block the others. `TaskPerformed(id, success, nextRunAt)` is emitted for each executed
    task.

## What the tests check

- Registration, cancellation and their access control and revert conditions.
- Due-task selection: ordering, the `maxBatch` cap and `checkData` ranges.
- Re-validation in `performUpkeep`: stale, duplicate, unknown and cancelled ids.
- Rescheduling, including catch-up after several missed intervals.
- Isolation of failing targets and behaviour when a target calls back into the scheduler.
