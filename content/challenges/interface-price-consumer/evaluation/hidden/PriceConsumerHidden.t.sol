// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PriceConsumer.sol";

/// A provider the consumer has never seen: different decimals and a price that
/// depends on the block number.
contract SteppingFeed is IPriceFeed {
    uint256 public immutable base;
    uint256 public immutable startBlock;

    constructor(uint256 base_) {
        base = base_;
        startBlock = block.number;
    }

    function latestPrice() external view returns (uint256) {
        return base + (block.number - startBlock) * 1e18;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}

contract WholeNumberFeed is IPriceFeed {
    function latestPrice() external pure returns (uint256) {
        return 37;
    }

    function decimals() external pure returns (uint8) {
        return 0;
    }
}

contract PriceConsumerHiddenTest is Test {
    address public alice = address(0xA11CE);

    function testHiddenWorksWithForeignImplementation() public {
        SteppingFeed stepping = new SteppingFeed(10e18);
        PriceConsumer consumer = new PriceConsumer(stepping);

        assertEq(consumer.currentPrice(), 10e18);
        assertEq(consumer.quote(4), 40);

        vm.roll(block.number + 5);
        assertEq(consumer.currentPrice(), 15e18);
        assertEq(consumer.quote(4), 60);
        assertTrue(consumer.isAtLeast(15e18));
        assertFalse(consumer.isAtLeast(15e18 + 1));
    }

    function testHiddenZeroDecimals() public {
        PriceConsumer consumer = new PriceConsumer(new WholeNumberFeed());
        assertEq(consumer.currentPrice(), 37);
        assertEq(consumer.quote(0), 0);
        assertEq(consumer.quote(100), 3_700);
        assertTrue(consumer.isAtLeast(0));
        assertTrue(consumer.isAtLeast(37));
        assertFalse(consumer.isAtLeast(38));
    }

    function testHiddenQuoteRoundsDown() public {
        // price 0.333333 with 6 decimals
        FixedPriceFeed priceFeed = new FixedPriceFeed(333_333, 6);
        PriceConsumer consumer = new PriceConsumer(priceFeed);
        assertEq(consumer.quote(1), 0);
        assertEq(consumer.quote(3), 0);
        assertEq(consumer.quote(4), 1);
        assertEq(consumer.quote(3_000_000), 999_999);
        assertEq(consumer.quote(3_000_004), 1_000_000);
    }

    function testHiddenConsumerRejectsZeroFeed() public {
        try new PriceConsumer(IPriceFeed(address(0))) returns (PriceConsumer) {
            assertTrue(false, "zero feed accepted");
        } catch (bytes memory reason) {
            assertEq(bytes32(reason), bytes32(PriceConsumer.ZeroFeed.selector));
        }
    }

    function testHiddenProviderRejectsZeroPrice() public {
        try new FixedPriceFeed(0, 8) returns (FixedPriceFeed) {
            assertTrue(false, "zero price accepted");
        } catch (bytes memory reason) {
            assertEq(bytes32(reason), bytes32(FixedPriceFeed.ZeroPrice.selector));
        }

        FixedPriceFeed priceFeed = new FixedPriceFeed(5, 2);
        vm.expectRevert(FixedPriceFeed.ZeroPrice.selector);
        priceFeed.setPrice(0);
        assertEq(priceFeed.latestPrice(), 5);
    }

    function testHiddenOwnerCheckRunsBeforePriceCheck() public {
        FixedPriceFeed priceFeed = new FixedPriceFeed(5, 2);
        vm.prank(alice);
        vm.expectRevert(FixedPriceFeed.NotOwner.selector);
        priceFeed.setPrice(0);
    }

    function testHiddenOwnerIsDeployerAndCanUpdateRepeatedly() public {
        vm.prank(alice);
        FixedPriceFeed priceFeed = new FixedPriceFeed(100, 2);
        assertEq(priceFeed.owner(), alice);

        vm.expectRevert(FixedPriceFeed.NotOwner.selector);
        priceFeed.setPrice(200);

        PriceConsumer consumer = new PriceConsumer(priceFeed);
        vm.prank(alice);
        priceFeed.setPrice(250);
        assertEq(consumer.quote(10), 25);
        vm.prank(alice);
        priceFeed.setPrice(1);
        assertEq(consumer.currentPrice(), 1);
        assertEq(consumer.quote(199), 1);
        assertEq(uint256(priceFeed.decimals()), 2);
    }

    function testHiddenTwoConsumersShareOneProvider() public {
        FixedPriceFeed priceFeed = new FixedPriceFeed(7e8, 8);
        PriceConsumer first = new PriceConsumer(priceFeed);
        PriceConsumer second = new PriceConsumer(priceFeed);
        priceFeed.setPrice(9e8);
        assertEq(first.currentPrice(), 9e8);
        assertEq(second.currentPrice(), 9e8);
        assertEq(first.quote(11), second.quote(11));
        assertEq(first.quote(11), 99);
    }
}
