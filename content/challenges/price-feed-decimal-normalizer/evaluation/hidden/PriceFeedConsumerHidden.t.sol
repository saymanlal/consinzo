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

contract PriceFeedConsumerHiddenTest is Test {
    uint256 internal constant MAX_AGE = 30 minutes;

    function _make(uint8 decimals_) internal returns (MockAggregator f, PriceFeedConsumer c) {
        f = new MockAggregator(decimals_);
        c = new PriceFeedConsumer(address(f), MAX_AGE);
    }

    function testHiddenZeroFeedRejected() public {
        vm.expectRevert(PriceFeedConsumer.ZeroAddress.selector);
        new PriceFeedConsumer(address(0), MAX_AGE);
    }

    function testHiddenScalesDownAboveEighteenDecimals() public {
        (MockAggregator f, PriceFeedConsumer c) = _make(24);
        f.setRound(1_234_567_890_123_456_789_999_999, block.timestamp); // 1.234567890123456789999999
        assertEq(c.latestPrice(), 1_234_567_890_123_456_789); // truncated, not rounded up
    }

    function testHiddenOddDecimals() public {
        (MockAggregator f0, PriceFeedConsumer c0) = _make(0);
        f0.setRound(7, block.timestamp);
        assertEq(c0.latestPrice(), 7e18);

        (MockAggregator f17, PriceFeedConsumer c17) = _make(17);
        f17.setRound(15, block.timestamp);
        assertEq(c17.latestPrice(), 150);

        (MockAggregator f19, PriceFeedConsumer c19) = _make(19);
        f19.setRound(159, block.timestamp);
        assertEq(c19.latestPrice(), 15);
    }

    function testHiddenStalenessBoundary() public {
        (MockAggregator f, PriceFeedConsumer c) = _make(8);
        uint256 t0 = block.timestamp;
        f.setRound(1e8, t0);

        vm.warp(t0 + MAX_AGE); // exactly maxAge old: accepted
        assertEq(c.latestPrice(), 1e18);

        vm.warp(t0 + MAX_AGE + 1);
        vm.expectRevert(PriceFeedConsumer.StalePrice.selector);
        c.latestPrice();

        f.setRound(2e8, block.timestamp); // a fresh round makes the feed usable again
        assertEq(c.latestPrice(), 2e18);
    }

    function testHiddenNeverUpdatedOrFutureRound() public {
        (MockAggregator f, PriceFeedConsumer c) = _make(8);
        f.setRound(1e8, 0);
        vm.expectRevert(PriceFeedConsumer.StalePrice.selector);
        c.latestPrice();

        f.setRound(1e8, block.timestamp + 1);
        vm.expectRevert(PriceFeedConsumer.StalePrice.selector);
        c.latestPrice();
    }

    function testHiddenInvalidPriceCheckedBeforeStaleness() public {
        (MockAggregator f, PriceFeedConsumer c) = _make(8);
        f.setRound(-5e8, 0); // both invalid and never updated
        vm.expectRevert(PriceFeedConsumer.InvalidPrice.selector);
        c.latestPrice();
    }

    function testHiddenNegativeAnswerNeverBecomesHugePrice() public {
        (MockAggregator f, PriceFeedConsumer c) = _make(18);
        f.setRound(type(int256).min, block.timestamp);
        vm.expectRevert(PriceFeedConsumer.InvalidPrice.selector);
        c.toQuote(1 ether, 18);
    }

    function testHiddenToQuoteAcrossBaseDecimals() public {
        (MockAggregator f, PriceFeedConsumer c) = _make(8);
        f.setRound(30_000e8, block.timestamp); // BTC / USD

        assertEq(c.toQuote(0.5e8, 8), 15_000e18); // 0.5 WBTC
        assertEq(c.toQuote(1, 8), 30_000e10); // one satoshi
        assertEq(c.toQuote(0, 8), 0);

        f.setRound(99_990_000, block.timestamp); // 0.9999 USD per USDC
        assertEq(c.toQuote(1_000_001, 6), 999_900_999_900_000_000); // 1.000001 * 0.9999
    }

    function testHiddenToQuoteRoundsDown() public {
        (MockAggregator f, PriceFeedConsumer c) = _make(18);
        f.setRound(1, block.timestamp); // 1 wei of quote per whole base unit
        assertEq(c.toQuote(1 ether - 1, 18), 0);
        assertEq(c.toQuote(1 ether, 18), 1);
        assertEq(c.toQuote(3 ether - 1, 18), 2);
    }

    function testHiddenToQuoteRevertsWhenStale() public {
        (MockAggregator f, PriceFeedConsumer c) = _make(8);
        uint256 t0 = block.timestamp;
        f.setRound(1e8, t0);
        vm.warp(t0 + MAX_AGE + 1);
        vm.expectRevert(PriceFeedConsumer.StalePrice.selector);
        c.toQuote(1 ether, 18);
    }
}
