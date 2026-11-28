// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PriceFeedConsumer.sol";

contract MockAggregator is IAggregatorV3 {
    uint8 public override decimals;
    int256 public answer;
    uint256 public updatedAt;
    uint80 public roundId;

    constructor(uint8 decimals_) {
        decimals = decimals_;
    }

    function setRound(int256 answer_, uint256 updatedAt_) external {
        answer = answer_;
        updatedAt = updatedAt_;
        roundId += 1;
    }

    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }
}

contract PriceFeedConsumerTest is Test {
    uint256 internal constant MAX_AGE = 1 hours;

    MockAggregator public usdFeed; // 8 decimals, like ETH / USD
    PriceFeedConsumer public consumer;

    function setUp() public {
        usdFeed = new MockAggregator(8);
        consumer = new PriceFeedConsumer(address(usdFeed), MAX_AGE);
    }

    function testStoresConfiguration() public view {
        assertEq(address(consumer.feed()), address(usdFeed));
        assertEq(consumer.maxAge(), MAX_AGE);
    }

    function testScalesEightDecimalsUp() public {
        usdFeed.setRound(2_000e8, block.timestamp);
        assertEq(consumer.latestPrice(), 2_000e18);

        usdFeed.setRound(123_456_789, block.timestamp); // 1.23456789
        assertEq(consumer.latestPrice(), 1.23456789e18);
    }

    function testEighteenDecimalsUnchanged() public {
        MockAggregator ethFeed = new MockAggregator(18);
        PriceFeedConsumer c = new PriceFeedConsumer(address(ethFeed), MAX_AGE);
        ethFeed.setRound(0.0005 ether, block.timestamp);
        assertEq(c.latestPrice(), 0.0005 ether);
    }

    function testRejectsNonPositiveAnswer() public {
        usdFeed.setRound(0, block.timestamp);
        vm.expectRevert(PriceFeedConsumer.InvalidPrice.selector);
        consumer.latestPrice();

        usdFeed.setRound(-1, block.timestamp);
        vm.expectRevert(PriceFeedConsumer.InvalidPrice.selector);
        consumer.latestPrice();
    }

    function testRejectsStaleAnswer() public {
        uint256 t0 = block.timestamp;
        usdFeed.setRound(2_000e8, t0);
        vm.warp(t0 + MAX_AGE + 1);
        vm.expectRevert(PriceFeedConsumer.StalePrice.selector);
        consumer.latestPrice();
    }

    function testToQuoteForEtherAmount() public {
        usdFeed.setRound(2_000e8, block.timestamp);
        assertEq(consumer.toQuote(1.5 ether, 18), 3_000e18);
    }
}
