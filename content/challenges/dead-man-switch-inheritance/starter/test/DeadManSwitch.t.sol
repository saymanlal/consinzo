// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DeadManSwitch.sol";

contract DeadManSwitchTest is Test {
    DeadManSwitch public wallet;
    address public owner = address(0x0A11CE);
    address public heir = address(0xB0B);
    address public stranger = address(0xDEAD01);

    uint256 constant PERIOD = 30 days;
    uint256 start;

    function setUp() public {
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        wallet = new DeadManSwitch{value: 10 ether}(heir, PERIOD);
        start = block.timestamp;
    }

    function testInitialState() public view {
        assertEq(wallet.owner(), owner);
        assertEq(wallet.heir(), heir);
        assertEq(wallet.silencePeriod(), PERIOD);
        assertEq(wallet.lastHeartbeat(), start);
        assertEq(wallet.claimableAt(), start + PERIOD);
        assertEq(address(wallet).balance, 10 ether);
    }

    function testHeartbeatPostponesClaim() public {
        vm.warp(start + 20 days);
        vm.prank(owner);
        wallet.heartbeat();
        assertEq(wallet.lastHeartbeat(), start + 20 days);
        assertEq(wallet.claimableAt(), start + 50 days);

        // 30 days after deployment the heir would have been able to claim without the heartbeat.
        vm.warp(start + 31 days);
        vm.prank(heir);
        vm.expectRevert(DeadManSwitch.OwnerStillActive.selector);
        wallet.claim();
        assertEq(wallet.owner(), owner);
    }

    function testHeirClaimsAfterSilence() public {
        vm.warp(start + PERIOD);
        vm.prank(heir);
        wallet.claim();

        assertEq(wallet.owner(), heir);
        assertEq(wallet.heir(), address(0));
        assertEq(wallet.lastHeartbeat(), start + PERIOD);
        assertEq(address(wallet).balance, 10 ether);
    }

    function testNewOwnerCanWithdraw() public {
        vm.warp(start + PERIOD + 1);
        vm.prank(heir);
        wallet.claim();

        vm.prank(heir);
        wallet.withdraw(4 ether);
        assertEq(heir.balance, 4 ether);
        assertEq(address(wallet).balance, 6 ether);
    }

    function testOwnerWithdrawCountsAsHeartbeat() public {
        vm.warp(start + 10 days);
        vm.prank(owner);
        wallet.withdraw(1 ether);
        assertEq(owner.balance, 1 ether);
        assertEq(wallet.lastHeartbeat(), start + 10 days);
    }
}
