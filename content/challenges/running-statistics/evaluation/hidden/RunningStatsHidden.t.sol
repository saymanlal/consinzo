// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RunningStats.sol";

contract RunningStatsHiddenTest is Test {
    RunningStats public stats;

    function setUp() public {
        stats = new RunningStats();
    }

    function testHiddenAllViewsRevertWithoutData() public {
        vm.expectRevert(RunningStats.NoData.selector);
        stats.min();
        vm.expectRevert(RunningStats.NoData.selector);
        stats.max();
        vm.expectRevert(RunningStats.NoData.selector);
        stats.average();
    }

    function testHiddenMinIsNotStuckAtZero() public {
        stats.submit(500);
        stats.submit(700);
        stats.submit(600);
        assertEq(stats.min(), 500);
        assertEq(stats.max(), 700);
    }

    function testHiddenZeroIsARealValue() public {
        stats.submit(0);
        assertEq(stats.count(), 1);
        assertEq(stats.min(), 0);
        assertEq(stats.max(), 0);
        assertEq(stats.average(), 0);

        stats.submit(9);
        assertEq(stats.min(), 0);
        assertEq(stats.max(), 9);
        assertEq(stats.average(), 4);
    }

    function testHiddenZeroAfterNonZero() public {
        stats.submit(8);
        stats.submit(0);
        assertEq(stats.min(), 0);
        assertEq(stats.max(), 8);
        assertEq(stats.count(), 2);
    }

    function testHiddenDescendingAndAscendingOrders() public {
        stats.submit(30);
        stats.submit(20);
        stats.submit(10);
        assertEq(stats.min(), 10);
        assertEq(stats.max(), 30);

        RunningStats other = new RunningStats();
        other.submit(10);
        other.submit(20);
        other.submit(30);
        assertEq(other.min(), 10);
        assertEq(other.max(), 30);
        assertEq(other.average(), 20);
    }

    function testHiddenAverageRoundsDown() public {
        stats.submit(1);
        stats.submit(2);
        assertEq(stats.average(), 1);
        stats.submit(2);
        assertEq(stats.average(), 1);
        stats.submit(3);
        assertEq(stats.average(), 2);
    }

    function testHiddenBatchMatchesSingles() public {
        uint256[] memory values = new uint256[](5);
        values[0] = 7;
        values[1] = 3;
        values[2] = 99;
        values[3] = 3;
        values[4] = 12;
        stats.submitBatch(values);

        assertEq(stats.count(), 5);
        assertEq(stats.sum(), 124);
        assertEq(stats.min(), 3);
        assertEq(stats.max(), 99);
        assertEq(stats.average(), 24);

        stats.submit(1);
        assertEq(stats.min(), 1);
        assertEq(stats.count(), 6);
    }

    function testHiddenEmptyBatchChangesNothing() public {
        uint256[] memory none = new uint256[](0);
        stats.submitBatch(none);
        assertEq(stats.count(), 0);
        vm.expectRevert(RunningStats.NoData.selector);
        stats.min();

        stats.submit(5);
        stats.submitBatch(none);
        assertEq(stats.count(), 1);
        assertEq(stats.min(), 5);
        assertEq(stats.max(), 5);
    }

    function testHiddenLargeValues() public {
        uint256 big = type(uint256).max / 2;
        stats.submit(big);
        stats.submit(big);
        assertEq(stats.sum(), big * 2);
        assertEq(stats.average(), big);
        assertEq(stats.min(), big);
        assertEq(stats.max(), big);

        // One more would overflow the sum.
        vm.expectRevert();
        stats.submit(2);
        assertEq(stats.count(), 2);
    }
}
