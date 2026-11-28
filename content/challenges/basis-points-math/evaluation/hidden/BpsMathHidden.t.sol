// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BpsMath.sol";

contract BpsMathHiddenTest is Test {
    BpsMath public math;
    uint256 internal constant MAX = type(uint256).max;

    function setUp() public {
        math = new BpsMath();
    }

    function testHiddenBoundaryRates() public view {
        assertEq(math.mulBpsDown(999, 0), 0);
        assertEq(math.mulBpsUp(999, 0), 0);
        assertEq(math.mulBpsDown(999, 10_000), 999);
        assertEq(math.mulBpsUp(999, 10_000), 999);
        assertEq(math.mulBpsDown(0, 5000), 0);
        assertEq(math.mulBpsUp(0, 5000), 0);
    }

    function testHiddenAllFunctionsValidateBps() public {
        vm.expectRevert(abi.encodeWithSelector(BpsMath.InvalidBps.selector, uint256(10_001)));
        math.mulBpsUp(1, 10_001);
        vm.expectRevert(abi.encodeWithSelector(BpsMath.InvalidBps.selector, uint256(20_000)));
        math.splitFee(1 ether, 20_000);
        vm.expectRevert(abi.encodeWithSelector(BpsMath.InvalidBps.selector, MAX));
        math.mulBpsDown(0, MAX);
    }

    function testHiddenRemainderCases() public view {
        // 9999 * 9999 / 10000 = 9998.0001
        assertEq(math.mulBpsDown(9999, 9999), 9998);
        assertEq(math.mulBpsUp(9999, 9999), 9999);
        // 3 * 3333 / 10000 = 0.9999
        assertEq(math.mulBpsDown(3, 3333), 0);
        assertEq(math.mulBpsUp(3, 3333), 1);
        // 20001 * 5000 / 10000 = 10000.5
        assertEq(math.mulBpsDown(20001, 5000), 10000);
        assertEq(math.mulBpsUp(20001, 5000), 10001);
        // exact: 1 ether * 30 / 10000
        assertEq(math.mulBpsDown(1 ether, 30), 3e15);
        assertEq(math.mulBpsUp(1 ether, 30), 3e15);
    }

    function testHiddenMaxAmountDoesNotOverflow() public view {
        assertEq(math.mulBpsDown(MAX, 10_000), MAX);
        assertEq(math.mulBpsUp(MAX, 10_000), MAX);

        // MAX is odd, so MAX / 10000 always leaves a remainder.
        assertEq(math.mulBpsDown(MAX, 1), MAX / 10_000);
        assertEq(math.mulBpsUp(MAX, 1), MAX / 10_000 + 1);

        // MAX * 5000 / 10000 = MAX / 2 exactly (floor) and one more when rounded up.
        assertEq(math.mulBpsDown(MAX, 5000), MAX / 2);
        assertEq(math.mulBpsUp(MAX, 5000), MAX / 2 + 1);
    }

    function testHiddenComplementIdentityOnLargeValues() public view {
        // floor(a * b / D) + ceil(a * (D - b) / D) == a for every a and b.
        uint256[4] memory amounts = [MAX, MAX - 12345, uint256(1) << 255, uint256(1e60) + 7];
        uint256[4] memory rates = [uint256(1), 250, 3333, 9999];
        for (uint256 i = 0; i < amounts.length; i++) {
            for (uint256 j = 0; j < rates.length; j++) {
                uint256 down = math.mulBpsDown(amounts[i], rates[j]);
                uint256 up = math.mulBpsUp(amounts[i], 10_000 - rates[j]);
                assertEq(down + up, amounts[i]);
            }
        }
    }

    function testHiddenUpNeverMoreThanOneAboveDown() public view {
        uint256[5] memory amounts = [uint256(1), 7, 10_001, 123_456_789, MAX];
        uint256[5] memory rates = [uint256(1), 33, 5000, 9999, 10_000];
        for (uint256 i = 0; i < amounts.length; i++) {
            for (uint256 j = 0; j < rates.length; j++) {
                uint256 down = math.mulBpsDown(amounts[i], rates[j]);
                uint256 up = math.mulBpsUp(amounts[i], rates[j]);
                assertGe(up, down);
                assertLe(up - down, 1);
                assertLe(up, amounts[i]);
            }
        }
    }

    function testHiddenSplitFeeAddsUp() public view {
        (uint256 fee, uint256 net) = math.splitFee(1, 1);
        assertEq(fee, 1);
        assertEq(net, 0);

        (fee, net) = math.splitFee(1 ether + 1, 30);
        assertEq(fee, 3e15 + 1);
        assertEq(net, 1 ether + 1 - (3e15 + 1));

        (fee, net) = math.splitFee(MAX, 9999);
        assertEq(fee + net, MAX);
        assertEq(fee, math.mulBpsUp(MAX, 9999));

        (fee, net) = math.splitFee(5000, 0);
        assertEq(fee, 0);
        assertEq(net, 5000);

        (fee, net) = math.splitFee(5000, 10_000);
        assertEq(fee, 5000);
        assertEq(net, 0);
    }
}
