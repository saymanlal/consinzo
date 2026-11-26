// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TimelockController.sol";

contract TargetMockH {
    uint256 public value;
    function setValue(uint256 v) external { value = v; }
}

contract TimelockControllerHiddenTest is Test {
    TimelockController public timelock;
    TargetMockH public target;

    function setUp() public {
        timelock = new TimelockController(address(this));
        target = new TargetMockH();
    }

    function testHiddenExpiredGracePeriodReverts() public {
        uint256 eta = block.timestamp + 2 days;
        bytes memory data = abi.encodeWithSelector(TargetMockH.setValue.selector, 7);
        timelock.queue(address(target), 0, data, eta);
        vm.warp(eta + 14 days + 1);
        vm.expectRevert();
        timelock.execute(address(target), 0, data, eta);
    }

    function testHiddenNonAdminRejected() public {
        uint256 eta = block.timestamp + 2 days;
        vm.prank(address(0xBAD));
        vm.expectRevert();
        timelock.queue(address(target), 0, "", eta);
    }
}
