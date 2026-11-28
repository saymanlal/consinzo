// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RunningStats.sol";

contract RunningStatsTest is Test {
    RunningStats public stats;

    function setUp() public {
        stats = new RunningStats();
    }

    function testStartsEmpty() public view {
        assertEq(stats.count(), 0);
        assertEq(stats.sum(), 0);
    }

    function testSingleValue() public {
        stats.submit(42);
        assertEq(stats.count(), 1);
        assertEq(stats.sum(), 42);
        assertEq(stats.min(), 42);
        assertEq(stats.max(), 42);
        assertEq(stats.average(), 42);
    }

    function testSeveralValues() public {
        stats.submit(10);
        stats.submit(4);
        stats.submit(25);
        assertEq(stats.count(), 3);
        assertEq(stats.sum(), 39);
        assertEq(stats.min(), 4);
        assertEq(stats.max(), 25);
        assertEq(stats.average(), 13);
    }

    function testNoDataReverts() public {
        vm.expectRevert(RunningStats.NoData.selector);
        stats.average();
    }
}
