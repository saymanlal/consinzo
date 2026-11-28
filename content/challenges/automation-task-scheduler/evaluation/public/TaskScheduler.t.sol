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

contract TaskSchedulerTest is Test {
    TaskScheduler public scheduler;
    Counter public a;
    Counter public b;
    address public alice = address(0xA11CE);
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

    function _check() internal view returns (bool needed, uint256[] memory ids, bytes memory performData) {
        (needed, performData) = scheduler.checkUpkeep("");
        ids = abi.decode(performData, (uint256[]));
    }

    function testRegisterStoresTask() public {
        bytes memory data = _poke();
        vm.prank(alice);
        uint256 id = scheduler.registerTask(address(a), data, 1 hours, t0 + 600);
        assertEq(id, 1);
        assertEq(scheduler.taskCount(), 1);

        (address owner, address target, uint64 interval, uint64 nextRunAt, bool active, uint32 runs, uint32 failures) =
            scheduler.getTask(id);
        assertEq(owner, alice);
        assertEq(target, address(a));
        assertEq(uint256(interval), 1 hours);
        assertEq(uint256(nextRunAt), uint256(t0) + 600);
        assertTrue(active);
        assertEq(uint256(runs), 0);
        assertEq(uint256(failures), 0);
        assertFalse(scheduler.isDue(id));
    }

    function testCheckUpkeepReportsOnlyDueTasks() public {
        scheduler.registerTask(address(a), _poke(), 1 hours, t0 + 100);
        scheduler.registerTask(address(b), _poke(), 1 hours, t0 + 500);

        (bool needed, uint256[] memory ids,) = _check();
        assertFalse(needed);
        assertEq(ids.length, 0);

        vm.warp(t0 + 100);
        (needed, ids,) = _check();
        assertTrue(needed);
        assertEq(ids.length, 1);
        assertEq(ids[0], 1);

        vm.warp(t0 + 500);
        (needed, ids,) = _check();
        assertEq(ids.length, 2);
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);
    }

    function testPerformUpkeepRunsAndReschedules() public {
        scheduler.registerTask(address(a), _poke(), 1 hours, t0 + 100);
        vm.warp(t0 + 100);
        (,, bytes memory performData) = _check();
        scheduler.performUpkeep(performData);

        assertEq(a.count(), 1);
        (,,, uint64 nextRunAt,, uint32 runs,) = scheduler.getTask(1);
        assertEq(uint256(nextRunAt), uint256(t0) + 100 + 1 hours);
        assertEq(uint256(runs), 1);

        (bool needed,,) = _check();
        assertFalse(needed);
    }

    function testPerformUpkeepRevertsWhenNothingDue() public {
        scheduler.registerTask(address(a), _poke(), 1 hours, t0 + 100);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        bytes memory performData = abi.encode(ids);
        vm.expectRevert(TaskScheduler.NothingDue.selector);
        scheduler.performUpkeep(performData);
        assertEq(a.count(), 0);
    }

    function testCancelledTaskIsNotSelected() public {
        scheduler.registerTask(address(a), _poke(), 1 hours, t0);
        scheduler.cancelTask(1);
        (bool needed,,) = _check();
        assertFalse(needed);
        assertFalse(scheduler.isDue(1));
    }

    function testFailingTargetDoesNotBlockBatch() public {
        scheduler.registerTask(address(a), abi.encodeWithSelector(Counter.alwaysFail.selector), 1 hours, t0);
        scheduler.registerTask(address(b), _poke(), 1 hours, t0);
        (,, bytes memory performData) = _check();
        scheduler.performUpkeep(performData);

        assertEq(b.count(), 1);
        (,,,,, uint32 runs, uint32 failures) = scheduler.getTask(1);
        assertEq(uint256(runs), 1);
        assertEq(uint256(failures), 1);
        (,,,,, runs, failures) = scheduler.getTask(2);
        assertEq(uint256(runs), 1);
        assertEq(uint256(failures), 0);
    }
}
