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
        if (maxBatch_ == 0) revert ZeroBatch();
        maxBatch = maxBatch_;
    }

    // ------------------------------------------------------------------ registry

    function registerTask(address target, bytes calldata data, uint64 interval, uint64 firstRunAt)
        external
        returns (uint256 id)
    {
        if (target == address(0)) revert ZeroAddress();
        if (interval == 0) revert ZeroInterval();
        if (firstRunAt < block.timestamp) revert StartInPast();

        id = ++taskCount;
        Task storage t = _tasks[id];
        t.owner = msg.sender;
        t.target = target;
        t.interval = interval;
        t.nextRunAt = firstRunAt;
        t.active = true;
        t.data = data;

        emit TaskRegistered(id, msg.sender, target, interval, firstRunAt);
    }

    function cancelTask(uint256 id) external {
        Task storage t = _tasks[id];
        // An unknown id has owner == address(0), which can never equal msg.sender.
        if (t.owner != msg.sender) revert NotTaskOwner();
        if (!t.active) revert TaskNotActive();
        t.active = false;
        emit TaskCancelled(id);
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
        Task storage t = _tasks[id];
        return t.active && block.timestamp >= t.nextRunAt;
    }

    // ------------------------------------------------------------------ automation interface

    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 lo = 1;
        uint256 hi = taskCount;
        if (checkData.length != 0) {
            (uint256 reqLo, uint256 reqHi) = abi.decode(checkData, (uint256, uint256));
            if (reqLo > lo) lo = reqLo;
            if (reqHi < hi) hi = reqHi;
        }

        // Collect into a buffer of the maximum size, then copy to an exactly sized array.
        uint256[] memory buffer = new uint256[](maxBatch);
        uint256 found;
        for (uint256 id = lo; id <= hi && found < maxBatch; ++id) {
            if (isDue(id)) {
                buffer[found++] = id;
            }
        }

        uint256[] memory ids = new uint256[](found);
        for (uint256 i = 0; i < found; ++i) {
            ids[i] = buffer[i];
        }

        return (found > 0, abi.encode(ids));
    }

    function performUpkeep(bytes calldata performData) external {
        uint256[] memory ids = abi.decode(performData, (uint256[]));
        if (ids.length > maxBatch) revert BatchTooLarge();

        uint256 performed;
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];

            // performData is untrusted and may be stale: decide from current state only.
            if (!isDue(id)) continue;

            Task storage t = _tasks[id];

            // Effects before the external call. Once nextRunAt is in the future the task is
            // no longer due, so a duplicate id later in the batch, or a target that calls
            // back into performUpkeep, cannot run it a second time.
            uint64 interval = t.interval;
            uint64 missed = (uint64(block.timestamp) - t.nextRunAt) / interval;
            uint64 nextRunAt = t.nextRunAt + interval * (missed + 1);
            t.nextRunAt = nextRunAt;
            t.runs += 1;
            ++performed;

            // A reverting target is recorded, not propagated, so it cannot block the batch.
            (bool success,) = t.target.call(t.data);
            if (!success) {
                t.failures += 1;
            }

            emit TaskPerformed(id, success, nextRunAt);
        }

        if (performed == 0) revert NothingDue();
    }
}
