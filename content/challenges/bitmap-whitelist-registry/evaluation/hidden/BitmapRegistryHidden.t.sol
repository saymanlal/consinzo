// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/BitmapRegistry.sol";

contract BitmapRegistryHiddenTest is Test {
    function testHiddenNonOwnerCannotMutate() public {
        BitmapRegistry reg = new BitmapRegistry();
        vm.prank(address(0xBAD));
        vm.expectRevert();
        reg.setFlag(10);
    }
}