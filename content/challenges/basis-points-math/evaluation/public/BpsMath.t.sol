// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BpsMath.sol";

contract BpsMathTest is Test {
    BpsMath public math;

    function setUp() public {
        math = new BpsMath();
    }

    function testDenominator() public view {
        assertEq(math.BPS_DENOMINATOR(), 10_000);
    }

    function testRoundDown() public view {
        assertEq(math.mulBpsDown(12345, 250), 308);
        assertEq(math.mulBpsDown(10000, 25), 25);
        assertEq(math.mulBpsDown(1, 1), 0);
    }

    function testRoundUp() public view {
        assertEq(math.mulBpsUp(12345, 250), 309);
        assertEq(math.mulBpsUp(10000, 25), 25);
        assertEq(math.mulBpsUp(1, 1), 1);
    }

    function testSplitFee() public view {
        (uint256 fee, uint256 net) = math.splitFee(12345, 250);
        assertEq(fee, 309);
        assertEq(net, 12036);
    }

    function testInvalidBpsReverts() public {
        vm.expectRevert(abi.encodeWithSelector(BpsMath.InvalidBps.selector, uint256(10_001)));
        math.mulBpsDown(100, 10_001);
    }
}
