// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/PackedStake.sol";

contract PackedStakeTest is Test {
    function testOverflowingUint96Reverts() public {
        PackedStake s = new PackedStake();
        uint256 tooLarge = uint256(type(uint96).max) + 1;
        vm.expectRevert();
        s.deposit(tooLarge);
    }

    function testValidAmountStoresAccurately() public {
        PackedStake s = new PackedStake();
        s.deposit(500 ether);
        (uint96 amt, ) = s.stakes(address(this));
        assertEq(uint256(amt), 500 ether);
    }
}