// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/BridgeReceiver.sol";

contract BridgeReceiverTest is Test {
    BridgeReceiver public bridge;
    address public relayer = address(0x555);
    address public remote = address(0x777);
    address public alice = address(0xA11CE);

    function setUp() public {
        bridge = new BridgeReceiver(relayer, 10, remote);
    }

    function testTrustedMessageWorksOnce() public {
        bytes32 id = keccak256("m1");
        vm.prank(relayer);
        bridge.receiveMessage(10, remote, id, alice, 100);
        assertEq(bridge.credited(alice), 100);

        vm.prank(relayer);
        vm.expectRevert();
        bridge.receiveMessage(10, remote, id, alice, 100);
    }

    function testSpoofedChainOrSenderReverts() public {
        vm.prank(relayer);
        vm.expectRevert();
        bridge.receiveMessage(999, remote, keccak256("m2"), alice, 100);

        vm.prank(relayer);
        vm.expectRevert();
        bridge.receiveMessage(10, address(0xBAD), keccak256("m3"), alice, 100);
    }
}