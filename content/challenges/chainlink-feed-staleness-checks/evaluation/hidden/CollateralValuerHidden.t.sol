// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CollateralValuer.sol";

contract MockAggregator is IAggregatorV3 {
    uint8 public immutable override decimals;
    uint80 internal _roundId;
    int256 internal _answer;
    uint256 internal _startedAt;
    uint256 internal _updatedAt;
    uint80 internal _answeredInRound;

    constructor(uint8 d) {
        decimals = d;
    }

    function setRound(uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) external {
        _roundId = roundId;
        _answer = answer;
        _startedAt = startedAt;
        _updatedAt = updatedAt;
        _answeredInRound = answeredInRound;
    }

    /// Convenience: a complete round answered right now.
    function push(int256 answer) external {
        _roundId += 1;
        _answer = answer;
        _startedAt = block.timestamp;
        _updatedAt = block.timestamp;
        _answeredInRound = _roundId;
    }

    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }
}

contract CollateralValuerHiddenTest is Test {
    MockAggregator public feed;
    CollateralValuer public valuer;
    uint256 internal constant T0 = 1_700_000_000;

    function setUp() public {
        vm.warp(T0);
        feed = new MockAggregator(8);
        valuer = new CollateralValuer(IAggregatorV3(address(feed)), 3600, 1e8, 100_000e8);
        feed.push(2_000e8);
    }

    function testHiddenExactlyAtHeartbeatIsFresh() public {
        vm.warp(T0 + 3600);
        assertEq(valuer.latestPrice(), 2_000e18);
    }

    function testHiddenOneSecondPastHeartbeatIsStale() public {
        vm.warp(T0 + 3601);
        vm.expectRevert(CollateralValuer.StalePrice.selector);
        valuer.maxBorrow(1e18);
    }

    function testHiddenCarriedOverAnswerReverts() public {
        // Round 7 reports the answer computed in round 5, with a fresh-looking timestamp.
        feed.setRound(7, 2_000e8, T0, T0, 5);
        vm.expectRevert(CollateralValuer.StaleRound.selector);
        valuer.latestPrice();
    }

    function testHiddenZeroAnswerReverts() public {
        feed.push(0);
        vm.expectRevert(CollateralValuer.InvalidPrice.selector);
        valuer.latestPrice();
    }

    function testHiddenLargeNegativeAnswerReverts() public {
        feed.push(-2_000e8);
        vm.expectRevert(CollateralValuer.InvalidPrice.selector);
        valuer.maxBorrow(1e18);
    }

    function testHiddenFutureTimestampReverts() public {
        feed.setRound(2, 2_000e8, T0, T0 + 1, 2);
        vm.expectRevert(CollateralValuer.IncompleteRound.selector);
        valuer.latestPrice();
    }

    function testHiddenClampedToMinimumReverts() public {
        feed.push(1e8); // the feed's floor: the real price may be far lower
        vm.expectRevert(CollateralValuer.PriceOutOfBounds.selector);
        valuer.latestPrice();
    }

    function testHiddenClampedToMaximumReverts() public {
        feed.push(100_000e8);
        vm.expectRevert(CollateralValuer.PriceOutOfBounds.selector);
        valuer.latestPrice();
    }

    function testHiddenJustInsideBoundsAccepted() public {
        feed.push(1e8 + 1);
        assertEq(valuer.latestPrice(), (1e8 + 1) * 1e10);
        feed.push(100_000e8 - 1);
        assertEq(valuer.latestPrice(), (100_000e8 - 1) * 1e10);
    }

    function testHiddenRecoversWhenFeedUpdates() public {
        vm.warp(T0 + 10_000);
        feed.push(1_500e8);
        assertEq(valuer.valueOf(2e18), 3_000e18);
        assertEq(valuer.maxBorrow(2e18), 2_250e18);
    }

    function testHiddenEighteenDecimalFeed() public {
        MockAggregator f18 = new MockAggregator(18);
        CollateralValuer v = new CollateralValuer(IAggregatorV3(address(f18)), 60, 1, 1_000_000e18);
        f18.push(123.5e18);
        assertEq(v.latestPrice(), 123.5e18);
        vm.warp(T0 + 61);
        vm.expectRevert(CollateralValuer.StalePrice.selector);
        v.latestPrice();
    }
}
