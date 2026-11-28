// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PriceConsumer.sol";

contract PriceConsumerTest is Test {
    FixedPriceFeed public priceFeed;
    PriceConsumer public consumer;
    address public alice = address(0xA11CE);

    function setUp() public {
        // 2,000.00000000 with 8 decimals
        priceFeed = new FixedPriceFeed(2_000e8, 8);
        consumer = new PriceConsumer(priceFeed);
    }

    function testProviderStoresPriceAndDecimals() public {
        assertEq(priceFeed.latestPrice(), 2_000e8);
        assertEq(uint256(priceFeed.decimals()), 8);
        assertEq(priceFeed.owner(), address(this));
    }

    function testConsumerReadsThroughInterface() public {
        assertEq(address(consumer.feed()), address(priceFeed));
        assertEq(consumer.currentPrice(), 2_000e8);
    }

    function testQuoteScalesByDecimals() public {
        assertEq(consumer.quote(3), 6_000);
        assertEq(consumer.quote(1 ether), 2_000 ether);
    }

    function testPriceUpdateIsVisibleImmediately() public {
        priceFeed.setPrice(2_500e8);
        assertEq(consumer.currentPrice(), 2_500e8);
        assertEq(consumer.quote(2), 5_000);
        assertTrue(consumer.isAtLeast(2_500e8));
        assertFalse(consumer.isAtLeast(2_500e8 + 1));
    }

    function testOnlyOwnerSetsPrice() public {
        vm.prank(alice);
        vm.expectRevert(FixedPriceFeed.NotOwner.selector);
        priceFeed.setPrice(1);
        assertEq(priceFeed.latestPrice(), 2_000e8);
    }
}
