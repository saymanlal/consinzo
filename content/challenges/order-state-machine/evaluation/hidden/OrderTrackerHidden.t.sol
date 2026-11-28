// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OrderTracker.sol";

contract OrderTrackerHiddenTest is Test {
    OrderTracker public tracker;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        tracker = new OrderTracker();
    }

    function _create(address buyer) internal returns (uint256 id) {
        vm.prank(buyer);
        id = tracker.createOrder();
    }

    function _status(uint256 id) internal view returns (uint256) {
        return uint256(tracker.statusOf(id));
    }

    function testHiddenUnknownOrder() public {
        assertEq(_status(1), uint256(OrderTracker.Status.None));
        assertEq(tracker.buyerOf(1), address(0));

        vm.expectRevert(abi.encodeWithSelector(OrderTracker.OrderNotFound.selector, uint256(1)));
        tracker.ship(1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OrderTracker.OrderNotFound.selector, uint256(0)));
        tracker.pay(0);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OrderTracker.OrderNotFound.selector, uint256(77)));
        tracker.confirmDelivery(77);
    }

    function testHiddenIdsAreSequential() public {
        assertEq(_create(alice), 1);
        assertEq(_create(bob), 2);
        assertEq(_create(alice), 3);
        assertEq(tracker.orderCount(), 3);
        assertEq(tracker.buyerOf(2), bob);
        assertEq(tracker.buyerOf(3), alice);
    }

    function testHiddenCannotPayTwice() public {
        uint256 id = _create(alice);
        vm.startPrank(alice);
        tracker.pay(id);
        vm.expectRevert(
            abi.encodeWithSelector(OrderTracker.InvalidState.selector, OrderTracker.Status.Paid)
        );
        tracker.pay(id);
        vm.stopPrank();
        assertEq(_status(id), uint256(OrderTracker.Status.Paid));
    }

    function testHiddenCannotSkipStates() public {
        uint256 id = _create(alice);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(OrderTracker.InvalidState.selector, OrderTracker.Status.Created)
        );
        tracker.confirmDelivery(id);

        vm.prank(alice);
        tracker.pay(id);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(OrderTracker.InvalidState.selector, OrderTracker.Status.Paid)
        );
        tracker.confirmDelivery(id);
    }

    function testHiddenDeliveredIsFinal() public {
        uint256 id = _create(alice);
        vm.prank(alice);
        tracker.pay(id);
        tracker.ship(id);
        vm.prank(alice);
        tracker.confirmDelivery(id);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(OrderTracker.InvalidState.selector, OrderTracker.Status.Delivered)
        );
        tracker.pay(id);

        vm.expectRevert(
            abi.encodeWithSelector(OrderTracker.InvalidState.selector, OrderTracker.Status.Delivered)
        );
        tracker.ship(id);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(OrderTracker.InvalidState.selector, OrderTracker.Status.Delivered)
        );
        tracker.confirmDelivery(id);
    }

    function testHiddenWrongParties() public {
        uint256 id = _create(alice);

        // The seller is not the buyer.
        vm.expectRevert(abi.encodeWithSelector(OrderTracker.NotBuyer.selector, address(this)));
        tracker.pay(id);

        vm.prank(alice);
        tracker.pay(id);

        // The buyer cannot ship their own order.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OrderTracker.NotSeller.selector, alice));
        tracker.ship(id);

        tracker.ship(id);

        // Another buyer cannot confirm someone else's delivery.
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OrderTracker.NotBuyer.selector, bob));
        tracker.confirmDelivery(id);

        assertEq(_status(id), uint256(OrderTracker.Status.Shipped));
    }

    function testHiddenCallerCheckedBeforeState() public {
        uint256 id = _create(alice);
        // Wrong caller and wrong state at once: the caller error wins.
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OrderTracker.NotSeller.selector, bob));
        tracker.ship(id);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OrderTracker.NotBuyer.selector, bob));
        tracker.confirmDelivery(id);
    }

    function testHiddenOrdersAreIndependent() public {
        uint256 first = _create(alice);
        uint256 second = _create(bob);

        vm.prank(alice);
        tracker.pay(first);
        tracker.ship(first);

        assertEq(_status(first), uint256(OrderTracker.Status.Shipped));
        assertEq(_status(second), uint256(OrderTracker.Status.Created));

        // Bob is a buyer, but not of the first order.
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OrderTracker.NotBuyer.selector, bob));
        tracker.confirmDelivery(first);

        vm.prank(bob);
        tracker.pay(second);
        assertEq(_status(second), uint256(OrderTracker.Status.Paid));
    }
}
