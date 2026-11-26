// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/BitmapRegistry.sol";

contract BitmapRegistryTest is Test {
    function testSetCheckAndClearFlags() public {
        BitmapRegistry reg = new BitmapRegistry();
        assertFalse(reg.hasFlag(0));
        reg.setFlag(0);
        reg.setFlag(255);
        reg.setFlag(256);
        assertTrue(reg.hasFlag(0));
        assertTrue(reg.hasFlag(255));
        assertTrue(reg.hasFlag(256));

        reg.clearFlag(255);
        assertFalse(reg.hasFlag(255));
        assertTrue(reg.hasFlag(0));
    }
}