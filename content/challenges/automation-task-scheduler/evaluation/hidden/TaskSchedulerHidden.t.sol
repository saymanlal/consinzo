// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TaskScheduler.sol";

contract Counter {
    uint256 public count;
    uint256 public value;

    function poke() external {
        count += 1;
    }

    function setValue(uint256 v) external {
        value = v;
        count += 1;
    }

    function alwaysFail() external pure {
        revert("TARGET_FAILED");
    }
}

/// Target that calls back into the scheduler while it is being executed.
contract Reenterer {
    TaskScheduler public scheduler;
    uint256 public taskId;
    uint256 public calls;
    bool public reentrySucceeded;

    constructor(TaskScheduler scheduler_) {
        scheduler = scheduler_;
    }

    function setTaskId(uint256 id) external {
        taskId = id;
    }

    function poke() external {
        calls += 1;
        uint256[] memory ids = new uint256[](1);
        ids[0] = taskId;
        (bool ok,) = address(scheduler).call(abi.encodeWithSelector(TaskScheduler.performUpkeep.selector, abi.encode(ids)));
        if (ok) reentrySucceeded = true;
    }
}

contract TaskSchedulerHiddenTest is Test {
    TaskScheduler public scheduler;
    Counter public a;
    Counter public b;
    address public alice = address(0xA11CE);
    address public keeper = address(0xBEEF);
    uint64 public t0;

    function setUp() public {
        scheduler = new TaskScheduler(3);
        a = new Counter();
        b = new Counter();
        t0 = uint64(block.timestamp);
    }

    function _poke() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(Counter.poke.selector);
    }

    function _ids(bytes memory checkData) internal view returns (bool needed, uint256[] memory ids) {
        bytes memory performData;
        (needed, performData) = scheduler.checkUpkeep(checkData);
        ids = abi.decode(performData, (uint256[]));
    }

    function _one(uint256 id) internal pure returns (bytes memory) {
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        return abi.encode(ids);
    }

    function testHiddenConstructorRejectsZeroBatch() public {
        vm.expectRevert(TaskScheduler.ZeroBatch.selector);
        new TaskScheduler(0);
    }

    function testHiddenRegisterValidation() public {
        bytes memory data = _poke();
        vm.expectRevert(TaskScheduler.ZeroAddress.selector);
        scheduler.registerTask(address(0), data, 0, t0 - 1);

        vm.expectRevert(TaskScheduler.ZeroInterval.selector);
        scheduler.registerTask(address(a), data, 0, t0 - 1);

        vm.expectRevert(TaskScheduler.StartInPast.selector);
        scheduler.registerTask(address(a), data, 60, t0 - 1);

        assertEq(scheduler.taskCount(), 0);

        // firstRunAt == now is allowed and immediately due
        uint256 id = scheduler.registerTask(address(a), data, 60, t0);
        assertEq(id, 1);
        assertTrue(scheduler.isDue(1));
        assertEq(scheduler.registerTask(address(b), data, 60, t0 + 1), 2);
        assertFalse(scheduler.isDue(2));
        assertFalse(scheduler.isDue(0));
        assertFalse(scheduler.isDue(3));
    }

    function testHiddenCancelAccessControl() public {
        bytes memory data = _poke();
        vm.prank(alice);
        scheduler.registerTask(address(a), data, 60, t0);

        vm.expectRevert(TaskScheduler.NotTaskOwner.selector);
        scheduler.cancelTask(1);

        vm.expectRevert(TaskScheduler.NotTaskOwner.selector);
        scheduler.cancelTask(99);

        vm.prank(alice);
        scheduler.cancelTask(1);

        vm.prank(alice);
        vm.expectRevert(TaskScheduler.TaskNotActive.selector);
        scheduler.cancelTask(1);
    }

    function testHiddenBatchCapTakesLowestIdsFirst() public {
        for (uint256 i = 0; i < 5; ++i) {
            scheduler.registerTask(address(a), _poke(), 1 hours, t0);
        }
        (bool needed, uint256[] memory ids) = _ids("");
        assertTrue(needed);
        assertEq(ids.length, 3);
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);
        assertEq(ids[2], 3);

        scheduler.performUpkeep(abi.encode(ids));
        assertEq(a.count(), 3);

        (needed, ids) = _ids("");
        assertEq(ids.length, 2);
        assertEq(ids[0], 4);
        assertEq(ids[1], 5);
        scheduler.performUpkeep(abi.encode(ids));
        assertEq(a.count(), 5);

        (needed, ids) = _ids("");
        assertFalse(needed);
        assertEq(ids.length, 0);
    }

    function testHiddenCheckDataRange() public {
        for (uint256 i = 0; i < 6; ++i) {
            scheduler.registerTask(address(a), _poke(), 1 hours, t0);
        }
        scheduler.cancelTask(5);

        (bool needed, uint256[] memory ids) = _ids(abi.encode(uint256(4), uint256(6)));
        assertTrue(needed);
        assertEq(ids.length, 2);
        assertEq(ids[0], 4);
        assertEq(ids[1], 6);

        (needed, ids) = _ids(abi.encode(uint256(0), uint256(2)));
        assertEq(ids.length, 2);
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);

        (needed, ids) = _ids(abi.encode(uint256(6), uint256(1000)));
        assertEq(ids.length, 1);
        assertEq(ids[0], 6);

        (needed, ids) = _ids(abi.encode(uint256(5), uint256(5)));
        assertFalse(needed);
        assertEq(ids.length, 0);

        (needed, ids) = _ids(abi.encode(uint256(4), uint256(2)));
        assertFalse(needed);
        assertEq(ids.length, 0);

        (needed, ids) = _ids(abi.encode(uint256(7), uint256(9)));
        assertFalse(needed);
    }

    function testHiddenDuplicateIdsRunOnce() public {
        scheduler.registerTask(address(a), _poke(), 1 hours, t0);
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 1;
        ids[2] = 1;
        scheduler.performUpkeep(abi.encode(ids));
        assertEq(a.count(), 1);
        (,,,,, uint32 runs,) = scheduler.getTask(1);
        assertEq(uint256(runs), 1);
    }

    function testHiddenStalePerformDataIsRevalidated() public {
        scheduler.registerTask(address(a), _poke(), 1 hours, t0); // 1: due, then cancelled
        scheduler.registerTask(address(b), _poke(), 1 hours, t0); // 2: due
        scheduler.registerTask(address(a), _poke(), 1 hours, t0 + 50); // 3: not due yet

        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 3;
        ids[2] = 2;
        bytes memory performData = abi.encode(ids);

        scheduler.cancelTask(1); // state changes between simulation and execution

        vm.prank(keeper);
        scheduler.performUpkeep(performData);
        assertEq(a.count(), 0);
        assertEq(b.count(), 1);

        // replaying the same bytes does nothing more
        vm.expectRevert(TaskScheduler.NothingDue.selector);
        scheduler.performUpkeep(performData);
        assertEq(b.count(), 1);
    }

    function testHiddenUnknownIdsAreSkipped() public {
        scheduler.registerTask(address(a), _poke(), 1 hours, t0);
        uint256[] memory ids = new uint256[](3);
        ids[0] = 0;
        ids[1] = 777;
        ids[2] = 1;
        scheduler.performUpkeep(abi.encode(ids));
        assertEq(a.count(), 1);

        ids[2] = 778;
        bytes memory performData = abi.encode(ids);
        vm.expectRevert(TaskScheduler.NothingDue.selector);
        scheduler.performUpkeep(performData);
    }

    function testHiddenBatchTooLarge() public {
        scheduler.registerTask(address(a), _poke(), 1 hours, t0);
        uint256[] memory ids = new uint256[](4);
        ids[0] = 1;
        bytes memory performData = abi.encode(ids);
        vm.expectRevert(TaskScheduler.BatchTooLarge.selector);
        scheduler.performUpkeep(performData);
        assertEq(a.count(), 0);

        uint256[] memory empty = new uint256[](0);
        performData = abi.encode(empty);
        vm.expectRevert(TaskScheduler.NothingDue.selector);
        scheduler.performUpkeep(performData);
    }

    function testHiddenCatchUpSkipsMissedSlots() public {
        scheduler.registerTask(address(a), _poke(), 100, t0 + 10);

        vm.warp(t0 + 10 + 250); // two and a half intervals late
        scheduler.performUpkeep(_one(1));
        assertEq(a.count(), 1);
        (,,, uint64 nextRunAt,,,) = scheduler.getTask(1);
        assertEq(uint256(nextRunAt), uint256(t0) + 10 + 300);
        assertFalse(scheduler.isDue(1));

        vm.warp(t0 + 10 + 299);
        assertFalse(scheduler.isDue(1));

        vm.warp(t0 + 10 + 400); // exactly on a later slot boundary
        assertTrue(scheduler.isDue(1));
        scheduler.performUpkeep(_one(1));
        (,,, nextRunAt,,,) = scheduler.getTask(1);
        assertEq(uint256(nextRunAt), uint256(t0) + 10 + 500);
        assertEq(a.count(), 2);
    }

    function testHiddenStoredCalldataIsForwarded() public {
        scheduler.registerTask(address(a), abi.encodeWithSelector(Counter.setValue.selector, uint256(4242)), 60, t0);
        scheduler.registerTask(address(b), abi.encodeWithSelector(Counter.setValue.selector, uint256(7)), 60, t0);
        (, uint256[] memory ids) = _ids("");
        vm.prank(keeper);
        scheduler.performUpkeep(abi.encode(ids));
        assertEq(a.value(), 4242);
        assertEq(b.value(), 7);
    }

    function testHiddenReentrantTargetCannotRunTwice() public {
        Reenterer r = new Reenterer(scheduler);
        uint256 id = scheduler.registerTask(address(r), abi.encodeWithSelector(Reenterer.poke.selector), 1 hours, t0);
        r.setTaskId(id);
        scheduler.registerTask(address(a), _poke(), 1 hours, t0);

        (, uint256[] memory ids) = _ids("");
        scheduler.performUpkeep(abi.encode(ids));

        assertEq(r.calls(), 1);
        assertFalse(r.reentrySucceeded());
        (,,, uint64 nextRunAt,, uint32 runs, uint32 failures) = scheduler.getTask(id);
        assertEq(uint256(runs), 1);
        assertEq(uint256(failures), 0);
        assertEq(uint256(nextRunAt), uint256(t0) + 1 hours);
        assertEq(a.count(), 1);
    }

    function testHiddenRepeatedFailuresAreCountedAndRescheduled() public {
        scheduler.registerTask(address(a), abi.encodeWithSelector(Counter.alwaysFail.selector), 100, t0);
        scheduler.performUpkeep(_one(1));
        vm.warp(t0 + 100);
        scheduler.performUpkeep(_one(1));
        vm.warp(t0 + 199);
        bytes memory performData = _one(1);
        vm.expectRevert(TaskScheduler.NothingDue.selector);
        scheduler.performUpkeep(performData);

        (,,, uint64 nextRunAt, bool active, uint32 runs, uint32 failures) = scheduler.getTask(1);
        assertTrue(active);
        assertEq(uint256(runs), 2);
        assertEq(uint256(failures), 2);
        assertEq(uint256(nextRunAt), uint256(t0) + 200);
    }
}
