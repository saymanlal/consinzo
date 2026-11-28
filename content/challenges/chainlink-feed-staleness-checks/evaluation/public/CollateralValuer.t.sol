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

contract CollateralValuerTest is Test {
    MockAggregator public feed;
    CollateralValuer public valuer;
    uint256 internal constant T0 = 1_700_000_000;

    function setUp() public {
        vm.warp(T0);
        feed = new MockAggregator(8);
        // 1 hour heartbeat, circuit breaker at $1 and $100,000 (8 decimals)
        valuer = new CollateralValuer(IAggregatorV3(address(feed)), 3600, 1e8, 100_000e8);
        feed.push(2_000e8);
    }

    function testFreshPriceIsScaledTo18Decimals() public {
        assertEq(valuer.latestPrice(), 2_000e18);
        assertEq(valuer.valueOf(3e18), 6_000e18);
        assertEq(valuer.maxBorrow(3e18), 4_500e18);
    }

    function testStalePriceReverts() public {
        vm.warp(T0 + 3601);
        vm.expectRevert(CollateralValuer.StalePrice.selector);
        valuer.latestPrice();
    }

    function testIncompleteRoundReverts() public {
        // Round 2 has started but has no answer yet.
        feed.setRound(2, 0, T0, 0, 1);
        vm.expectRevert(CollateralValuer.IncompleteRound.selector);
        valuer.latestPrice();
    }

    function testNegativeAnswerReverts() public {
        feed.push(-1);
        vm.expectRevert(CollateralValuer.InvalidPrice.selector);
        valuer.valueOf(1e18);
    }
}
