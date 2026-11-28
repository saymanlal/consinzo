// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MedianOracle.sol";

contract MedianOracleTest is Test {
    uint256 internal constant MAX_AGE = 1 hours;
    uint256 internal constant MAX_DEV = 200; // 2%

    MedianOracle public oracle;
    address[] internal reporters;

    function setUp() public {
        for (uint160 i = 1; i <= 5; i++) {
            reporters.push(address(0x1000 + i));
        }
        oracle = new MedianOracle(reporters, 3, MAX_AGE, MAX_DEV);
    }

    function _report(uint256 idx, uint256 price) internal {
        vm.prank(reporters[idx]);
        oracle.report(price);
    }

    function testConfiguration() public view {
        assertEq(oracle.owner(), address(this));
        assertEq(oracle.minReports(), 3);
        assertEq(oracle.maxAge(), MAX_AGE);
        assertEq(oracle.maxDeviationBps(), MAX_DEV);
        assertEq(oracle.reporterCount(), 5);
        assertTrue(oracle.isReporter(reporters[0]));
        assertFalse(oracle.isReporter(address(this)));
    }

    function testMedianOfOddCount() public {
        _report(0, 2_010e18);
        _report(1, 1_990e18);
        _report(2, 2_000e18);
        assertEq(oracle.freshCount(), 3);
        assertEq(oracle.latestPrice(), 2_000e18);
    }

    function testMedianOfEvenCount() public {
        _report(0, 2_000e18);
        _report(1, 2_004e18);
        _report(2, 1_998e18);
        _report(3, 2_002e18);
        assertEq(oracle.latestPrice(), 2_001e18);
    }

    function testOnlyReportersCanReport() public {
        vm.expectRevert(MedianOracle.NotReporter.selector);
        oracle.report(2_000e18);
    }

    function testNotEnoughReports() public {
        _report(0, 2_000e18);
        _report(1, 2_000e18);
        vm.expectRevert(MedianOracle.InsufficientReports.selector);
        oracle.latestPrice();
    }

    function testStaleReportsAreExcluded() public {
        uint256 t0 = block.timestamp;
        _report(0, 2_000e18);
        _report(1, 2_000e18);
        vm.warp(t0 + MAX_AGE + 1);
        _report(2, 2_000e18);
        assertEq(oracle.freshCount(), 1);
        vm.expectRevert(MedianOracle.InsufficientReports.selector);
        oracle.latestPrice();
    }

    function testDisagreementReverts() public {
        _report(0, 1_000e18);
        _report(1, 2_000e18);
        _report(2, 3_000e18);
        vm.expectRevert(MedianOracle.DeviationTooHigh.selector);
        oracle.latestPrice();
    }
}
