// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/PackedStake.sol";

contract PackedStakeHiddenTest is Test {
    function testHiddenMaxUint96Accepted() public {
        PackedStake s = new PackedStake();
        s.deposit(uint256(type(uint96).max));
        (uint96 amt, ) = s.stakes(address(this));
        assertEq(uint256(amt), uint256(type(uint96).max));
    }
}