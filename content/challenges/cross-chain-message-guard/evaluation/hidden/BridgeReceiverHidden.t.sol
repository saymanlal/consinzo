// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/BridgeReceiver.sol";

contract BridgeReceiverHiddenTest is Test {
    function testHiddenNonRelayerRejected() public {
        BridgeReceiver b = new BridgeReceiver(address(0x555), 10, address(0x777));
        vm.prank(address(0xBAD));
        vm.expectRevert();
        b.receiveMessage(10, address(0x777), keccak256("m4"), address(0xA11CE), 50);
    }
}