// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/VestingWallet.sol";

contract VestingWalletHiddenTest is Test {
    function testHiddenNonBeneficiaryCannotRelease() public {
        VestingWallet w = new VestingWallet{value: 4 ether}(address(0xA11CE), block.timestamp, 0, 100);
        vm.warp(block.timestamp + 200);
        vm.prank(address(0xBAD));
        vm.expectRevert();
        w.release();
    }
}