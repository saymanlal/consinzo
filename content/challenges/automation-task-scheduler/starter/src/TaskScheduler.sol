// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract TaskScheduler {
    struct Task {
        address owner;
        address target;
        uint64 interval;
        uint64 nextRunAt;
        bool active;
        uint32 runs;
        uint32 failures;
        bytes data;
    }

    uint256 public immutable maxBatch;
    uint256 public taskCount;

    mapping(uint256 => Task) internal _tasks;

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

    constructor(uint256 maxBatch_) {
        // TODO: revert with ZeroBatch() when maxBatch_ is zero
        maxBatch = maxBatch_;
    }

    function registerTask(address target, bytes calldata data, uint64 interval, uint64 firstRunAt)
        external
        returns (uint256 id)
    {
        // TODO: validate (ZeroAddress, ZeroInterval, StartInPast in that order)
        // TODO: assign the next id (starting at 1), store the task, emit TaskRegistered
        revert("NOT_IMPLEMENTED");
    }

    function cancelTask(uint256 id) external {
        // TODO: only the task owner (NotTaskOwner), only while active (TaskNotActive)
        revert("NOT_IMPLEMENTED");
    }

    function getTask(uint256 id)
        external
        view
        returns (
            address owner,
            address target,
            uint64 interval,
            uint64 nextRunAt,
            bool active,
            uint32 runs,
            uint32 failures
        )
    {
        Task storage t = _tasks[id];
        return (t.owner, t.target, t.interval, t.nextRunAt, t.active, t.runs, t.failures);
    }

    function isDue(uint256 id) public view returns (bool) {
        // TODO: active and block.timestamp >= nextRunAt
        return false;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // TODO: decode the optional (lo, hi) range from checkData and clamp it
        // TODO: collect due ids in ascending order, at most maxBatch
        // TODO: return (ids.length > 0, abi.encode(ids))
        return (false, abi.encode(new uint256[](0)));
    }

    function performUpkeep(bytes calldata performData) external {
        // TODO: decode ids, enforce BatchTooLarge
        // TODO: re-validate each id; skip the ones that are not due
        // TODO: update runs / nextRunAt before calling the target, count failures
        // TODO: revert with NothingDue() if nothing was executed
        revert("NOT_IMPLEMENTED");
    }
}
