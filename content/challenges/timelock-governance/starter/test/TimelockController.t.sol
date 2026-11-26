// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TimelockController.sol";

contract TargetMock {
    uint256 public value;
    function setValue(uint256 v) external { value = v; }
}

contract TimelockControllerTest is Test {
    TimelockController public timelock;
    TargetMock public target;

    function setUp() public {
        timelock = new TimelockController(address(this));
        target = new TargetMock();
    }

    function testQueueAndExecuteAfterDelay() public {
        uint256 eta = block.timestamp + 2 days;
        bytes memory data = abi.encodeWithSelector(TargetMock.setValue.selector, 42);
        bytes32 h = timelock.queue(address(target), 0, data, eta);
        assertTrue(timelock.queued(h));

        vm.warp(eta);
        timelock.execute(address(target), 0, data, eta);
        assertEq(target.value(), 42);
        assertFalse(timelock.queued(h));
    }

    function testEarlyExecutionReverts() public {
        uint256 eta = block.timestamp + 2 days;
        bytes memory data = abi.encodeWithSelector(TargetMock.setValue.selector, 99);
        timelock.queue(address(target), 0, data, eta);
        vm.expectRevert();
        timelock.execute(address(target), 0, data, eta);
    }
}
