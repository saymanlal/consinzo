// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MedianOracle.sol";

contract MedianOracleHiddenTest is Test {
    uint256 internal constant MAX_AGE = 30 minutes;
    uint256 internal constant MAX_DEV = 100; // 1%

    MedianOracle public oracle;
    address[] internal reporters;
    address internal outsider = address(0xBAD);

    function setUp() public {
        for (uint160 i = 1; i <= 5; i++) {
            reporters.push(address(0x2000 + i));
        }
        oracle = new MedianOracle(reporters, 3, MAX_AGE, MAX_DEV);
    }

    function _report(uint256 idx, uint256 price) internal {
        vm.prank(reporters[idx]);
        oracle.report(price);
    }

    function _list(uint256 n) internal pure returns (address[] memory list) {
        list = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            list[i] = address(uint160(0x3000 + i));
        }
    }

    // ------------------------------------------------------------ median

    function testHiddenMedianIndependentOfSubmissionOrder() public {
        _report(4, 10_050);
        _report(0, 10_010);
        _report(3, 9_990);
        _report(1, 10_030);
        _report(2, 10_000);
        assertEq(oracle.latestPrice(), 10_010);
    }

    function testHiddenEvenMedianRoundsDown() public {
        _report(0, 1_000);
        _report(1, 1_001);
        _report(2, 1_003);
        _report(3, 1_004);
        assertEq(oracle.latestPrice(), 1_002);
        _report(3, 1_000); // sorted: 1000 1000 1001 1003 -> (1000 + 1001) / 2
        assertEq(oracle.latestPrice(), 1_000);
    }

    function testHiddenReportOverwritesInsteadOfAccumulating() public {
        _report(0, 500);
        _report(0, 501);
        _report(0, 502);
        assertEq(oracle.freshCount(), 1);
        (uint128 price, uint64 updatedAt) = oracle.reports(reporters[0]);
        assertEq(uint256(price), 502);
        assertEq(uint256(updatedAt), block.timestamp);
        vm.expectRevert(MedianOracle.InsufficientReports.selector);
        oracle.latestPrice();
    }

    function testHiddenLargePricesDoNotOverflow() public {
        uint256 max = type(uint128).max;
        _report(0, max);
        _report(1, max);
        _report(2, max - 1);
        _report(3, max - 1);
        assertEq(oracle.latestPrice(), max - 1); // floor((2 * max - 1) / 2)
    }

    // ------------------------------------------------------------ input validation

    function testHiddenInvalidPrices() public {
        vm.prank(reporters[0]);
        vm.expectRevert(MedianOracle.InvalidPrice.selector);
        oracle.report(0);

        vm.prank(reporters[0]);
        vm.expectRevert(MedianOracle.InvalidPrice.selector);
        oracle.report(uint256(type(uint128).max) + 1);

        // the caller check comes first
        vm.prank(outsider);
        vm.expectRevert(MedianOracle.NotReporter.selector);
        oracle.report(0);
    }

    // ------------------------------------------------------------ staleness

    function testHiddenStalenessBoundaryAndRecovery() public {
        uint256 t0 = block.timestamp;
        _report(0, 100);
        _report(1, 100);
        _report(2, 100);

        vm.warp(t0 + MAX_AGE); // exactly maxAge old: still fresh
        assertEq(oracle.freshCount(), 3);
        assertEq(oracle.latestPrice(), 100);

        vm.warp(t0 + MAX_AGE + 1);
        assertEq(oracle.freshCount(), 0);
        vm.expectRevert(MedianOracle.InsufficientReports.selector);
        oracle.latestPrice();

        _report(0, 200);
        _report(3, 200);
        assertEq(oracle.freshCount(), 2);
        _report(4, 201);
        assertEq(oracle.latestPrice(), 200);
    }

    function testHiddenStaleReportsDoNotInfluenceMedian() public {
        uint256 t0 = block.timestamp;
        _report(0, 9_000);
        _report(1, 9_000);
        vm.warp(t0 + MAX_AGE + 1);
        _report(2, 100);
        _report(3, 100);
        _report(4, 101);
        // the two old 9000 reports would drag the median to 101 and break agreement
        assertEq(oracle.freshCount(), 3);
        assertEq(oracle.latestPrice(), 100);
    }

    // ------------------------------------------------------------ deviation

    function testHiddenAgreementBoundary() public {
        // median 10000, band 1% = 100
        _report(0, 9_900);
        _report(1, 10_000);
        _report(2, 10_100);
        assertEq(oracle.latestPrice(), 10_000);

        _report(0, 9_899); // one unit outside the band: only 2 of 3 agree
        vm.expectRevert(MedianOracle.DeviationTooHigh.selector);
        oracle.latestPrice();

        _report(3, 10_001); // sorted 9899 10000 10001 10100, median 10000, three agree
        assertEq(oracle.latestPrice(), 10_000);
    }

    function testHiddenOutlierIgnoredWhenQuorumAgrees() public {
        _report(0, 2_000e18);
        _report(1, 2_001e18);
        _report(2, 1_999e18);
        _report(3, uint256(type(uint128).max)); // absurdly high
        _report(4, 1); // absurdly low
        assertEq(oracle.latestPrice(), 2_000e18);
        (bool ok, uint256 price) = oracle.tryLatestPrice();
        assertTrue(ok);
        assertEq(price, 2_000e18);
    }

    function testHiddenMinorityCannotMoveMedianOutsideHonestRange() public {
        _report(0, 1_000e18);
        _report(1, 1_002e18);
        _report(2, 1_004e18);
        // two colluding reporters push as high as they can
        _report(3, 1_000_000e18);
        _report(4, 1_000_000e18);
        uint256 p = oracle.latestPrice();
        assertEq(p, 1_004e18);
        assertGe(p, 1_000e18);
        assertLe(p, 1_004e18);
    }

    function testHiddenEvenSplitFailsAgreement() public {
        MedianOracle two = new MedianOracle(_list(2), 2, MAX_AGE, 5_000);
        vm.prank(address(0x3000));
        two.report(100);
        vm.prank(address(0x3001));
        two.report(400); // median 250, band 125, both reports are 150 away
        vm.expectRevert(MedianOracle.DeviationTooHigh.selector);
        two.latestPrice();

        vm.prank(address(0x3001));
        two.report(300); // median 200, band 100, both exactly on the edge
        assertEq(two.latestPrice(), 200);
    }

    function testHiddenTryLatestPriceNeverReverts() public {
        (bool ok, uint256 price) = oracle.tryLatestPrice();
        assertFalse(ok);
        assertEq(price, 0);

        _report(0, 100);
        _report(1, 200);
        _report(2, 300);
        (ok, price) = oracle.tryLatestPrice(); // disagreement
        assertFalse(ok);
        assertEq(price, 0);

        _report(0, 200);
        _report(2, 200);
        (ok, price) = oracle.tryLatestPrice();
        assertTrue(ok);
        assertEq(price, 200);
    }

    // ------------------------------------------------------------ reporter management

    function testHiddenOnlyOwnerManagesReporters() public {
        vm.prank(outsider);
        vm.expectRevert(MedianOracle.NotOwner.selector);
        oracle.addReporter(outsider);

        vm.prank(reporters[0]);
        vm.expectRevert(MedianOracle.NotOwner.selector);
        oracle.removeReporter(reporters[1]);
    }

    function testHiddenAddReporterValidation() public {
        vm.expectRevert(MedianOracle.ZeroAddress.selector);
        oracle.addReporter(address(0));
        vm.expectRevert(MedianOracle.DuplicateReporter.selector);
        oracle.addReporter(reporters[2]);

        for (uint160 i = 0; i < 11; i++) {
            oracle.addReporter(address(0x4000 + i));
        }
        assertEq(oracle.reporterCount(), 16);
        vm.expectRevert(MedianOracle.TooManyReporters.selector);
        oracle.addReporter(address(0x5000));
    }

    function testHiddenRemovedReporterStopsCountingAndCannotReport() public {
        _report(0, 100);
        _report(1, 100);
        _report(2, 100);
        assertEq(oracle.latestPrice(), 100);

        oracle.removeReporter(reporters[1]);
        assertFalse(oracle.isReporter(reporters[1]));
        assertEq(oracle.reporterCount(), 4);
        assertEq(oracle.freshCount(), 2);
        vm.expectRevert(MedianOracle.InsufficientReports.selector);
        oracle.latestPrice();

        vm.prank(reporters[1]);
        vm.expectRevert(MedianOracle.NotReporter.selector);
        oracle.report(100);

        // the remaining reporters are intact after the removal
        _report(4, 101);
        assertEq(oracle.latestPrice(), 100);
    }

    function testHiddenReAddedReporterStartsWithoutReport() public {
        _report(0, 100);
        _report(1, 100);
        _report(2, 100);
        oracle.removeReporter(reporters[2]);
        oracle.addReporter(reporters[2]);

        (uint128 price, uint64 updatedAt) = oracle.reports(reporters[2]);
        assertEq(uint256(price), 0);
        assertEq(uint256(updatedAt), 0);
        assertEq(oracle.freshCount(), 2);

        _report(2, 101);
        assertEq(oracle.latestPrice(), 100);
    }

    function testHiddenCannotRemoveBelowQuorum() public {
        oracle.removeReporter(reporters[0]);
        oracle.removeReporter(reporters[1]);
        assertEq(oracle.reporterCount(), 3);
        vm.expectRevert(MedianOracle.InvalidConfig.selector);
        oracle.removeReporter(reporters[2]);

        vm.expectRevert(MedianOracle.NotReporter.selector);
        oracle.removeReporter(reporters[0]); // already removed
        assertTrue(oracle.isReporter(reporters[2]));
        assertTrue(oracle.isReporter(reporters[3]));
        assertTrue(oracle.isReporter(reporters[4]));
    }

    // ------------------------------------------------------------ constructor

    function testHiddenConstructorRejectsBadReporterLists() public {
        address[] memory dup = _list(3);
        dup[2] = dup[0];
        vm.expectRevert(MedianOracle.DuplicateReporter.selector);
        new MedianOracle(dup, 1, MAX_AGE, MAX_DEV);

        address[] memory zero = _list(3);
        zero[1] = address(0);
        vm.expectRevert(MedianOracle.ZeroAddress.selector);
        new MedianOracle(zero, 1, MAX_AGE, MAX_DEV);

        address[] memory many = _list(17);
        vm.expectRevert(MedianOracle.TooManyReporters.selector);
        new MedianOracle(many, 1, MAX_AGE, MAX_DEV);
    }

    function testHiddenConstructorRejectsBadConfig() public {
        address[] memory list = _list(3);
        vm.expectRevert(MedianOracle.InvalidConfig.selector);
        new MedianOracle(list, 0, MAX_AGE, MAX_DEV);
        vm.expectRevert(MedianOracle.InvalidConfig.selector);
        new MedianOracle(list, 4, MAX_AGE, MAX_DEV);
        vm.expectRevert(MedianOracle.InvalidConfig.selector);
        new MedianOracle(list, 3, 0, MAX_DEV);
        vm.expectRevert(MedianOracle.InvalidConfig.selector);
        new MedianOracle(list, 3, MAX_AGE, 0);
        vm.expectRevert(MedianOracle.InvalidConfig.selector);
        new MedianOracle(list, 3, MAX_AGE, 10_001);

        MedianOracle ok = new MedianOracle(list, 3, 1, 10_000);
        assertEq(ok.reporterCount(), 3);
    }
}
