// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OrderTracker.sol";

contract OrderTrackerTest is Test {
    OrderTracker public tracker;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        // The test contract is the seller.
        tracker = new OrderTracker();
    }

    function testCreateOrder() public {
        vm.prank(alice);
        uint256 id = tracker.createOrder();
        assertEq(id, 1);
        assertEq(tracker.orderCount(), 1);
        assertEq(tracker.buyerOf(id), alice);
        assertEq(uint256(tracker.statusOf(id)), uint256(OrderTracker.Status.Created));
        assertEq(tracker.seller(), address(this));
    }

    function testHappyPath() public {
        vm.prank(alice);
        uint256 id = tracker.createOrder();

        vm.prank(alice);
        tracker.pay(id);
        assertEq(uint256(tracker.statusOf(id)), uint256(OrderTracker.Status.Paid));

        tracker.ship(id);
        assertEq(uint256(tracker.statusOf(id)), uint256(OrderTracker.Status.Shipped));

        vm.prank(alice);
        tracker.confirmDelivery(id);
        assertEq(uint256(tracker.statusOf(id)), uint256(OrderTracker.Status.Delivered));
    }

    function testCannotShipBeforePayment() public {
        vm.prank(alice);
        uint256 id = tracker.createOrder();

        vm.expectRevert(
            abi.encodeWithSelector(OrderTracker.InvalidState.selector, OrderTracker.Status.Created)
        );
        tracker.ship(id);
    }

    function testOnlyBuyerPays() public {
        vm.prank(alice);
        uint256 id = tracker.createOrder();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OrderTracker.NotBuyer.selector, bob));
        tracker.pay(id);
    }
}
