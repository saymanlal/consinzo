// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SubscriptionBilling.sol";

contract SubscriptionBillingTest is Test {
    SubscriptionBilling public billing;
    address public merchant = address(0x3E4C);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    uint256 constant PRICE = 1 ether;
    uint256 constant PERIOD = 30 days;
    uint256 start;

    function setUp() public {
        vm.prank(merchant);
        billing = new SubscriptionBilling(PRICE, PERIOD);
        start = block.timestamp;
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function _sub(address who) internal view returns (uint256 balance, uint256 paidUntil, bool active) {
        return billing.subscriptions(who);
    }

    function testSubscribeChargesFirstPeriod() public {
        vm.prank(alice);
        billing.subscribe{value: 3 ether}();

        (uint256 balance, uint256 paidUntil, bool active) = _sub(alice);
        assertEq(balance, 2 ether);
        assertEq(paidUntil, start + PERIOD);
        assertTrue(active);
        assertEq(billing.merchantBalance(), 1 ether);
        assertTrue(billing.isPaid(alice));
    }

    function testChargeAfterPeriod() public {
        vm.prank(alice);
        billing.subscribe{value: 3 ether}();

        vm.warp(start + PERIOD);
        assertFalse(billing.isPaid(alice));
        vm.prank(merchant);
        billing.charge(alice);

        (uint256 balance, uint256 paidUntil, ) = _sub(alice);
        assertEq(balance, 1 ether);
        assertEq(paidUntil, start + 2 * PERIOD);
        assertEq(billing.merchantBalance(), 2 ether);
        assertTrue(billing.isPaid(alice));
    }

    function testCannotChargeBeforeDue() public {
        vm.prank(alice);
        billing.subscribe{value: 3 ether}();

        vm.warp(start + PERIOD - 1);
        vm.prank(merchant);
        vm.expectRevert(SubscriptionBilling.NotDue.selector);
        billing.charge(alice);
    }

    function testCancelAndWithdraw() public {
        vm.prank(alice);
        billing.subscribe{value: 3 ether}();

        vm.prank(alice);
        billing.cancel(alice);
        assertFalse(billing.isPaid(alice));

        vm.prank(alice);
        billing.withdraw();
        assertEq(alice.balance, 99 ether);
        (uint256 balance, , bool active) = _sub(alice);
        assertEq(balance, 0);
        assertFalse(active);
    }

    function testMerchantCollects() public {
        vm.prank(alice);
        billing.subscribe{value: 1 ether}();
        vm.prank(bob);
        billing.subscribe{value: 2 ether}();

        vm.prank(merchant);
        billing.collect();
        assertEq(merchant.balance, 2 ether);
        assertEq(billing.merchantBalance(), 0);
        assertEq(address(billing).balance, 1 ether);
    }
}
