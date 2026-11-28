// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SubscriptionBilling.sol";

contract SubscriptionBillingHiddenTest is Test {
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

    function _balance(address who) internal view returns (uint256 balance) {
        (balance, , ) = billing.subscriptions(who);
    }

    function _paidUntil(address who) internal view returns (uint256 paidUntil) {
        (, paidUntil, ) = billing.subscriptions(who);
    }

    function testHiddenSubscribeNeedsOnePeriod() public {
        vm.prank(alice);
        vm.expectRevert(SubscriptionBilling.InsufficientBalance.selector);
        billing.subscribe{value: PRICE - 1}();

        vm.prank(alice);
        billing.subscribe{value: PRICE}();
        assertEq(_balance(alice), 0);
        assertEq(billing.merchantBalance(), PRICE);
    }

    function testHiddenDoubleSubscribeReverts() public {
        vm.prank(alice);
        billing.subscribe{value: 2 ether}();
        vm.prank(alice);
        vm.expectRevert(SubscriptionBilling.AlreadySubscribed.selector);
        billing.subscribe{value: 2 ether}();
        assertEq(billing.merchantBalance(), PRICE);
    }

    function testHiddenCannotChargeTwiceInOnePeriod() public {
        vm.prank(alice);
        billing.subscribe{value: 5 ether}();
        vm.warp(start + PERIOD);

        vm.prank(merchant);
        billing.charge(alice);
        vm.prank(merchant);
        vm.expectRevert(SubscriptionBilling.NotDue.selector);
        billing.charge(alice);
        assertEq(billing.merchantBalance(), 2 ether);
    }

    function testHiddenLateChargeDoesNotShiftSchedule() public {
        vm.prank(alice);
        billing.subscribe{value: 5 ether}();

        // Ten days late: the period that is charged still started at start + PERIOD.
        vm.warp(start + PERIOD + 10 days);
        vm.prank(merchant);
        billing.charge(alice);
        assertEq(_paidUntil(alice), start + 2 * PERIOD);

        vm.warp(start + 2 * PERIOD - 1);
        vm.prank(merchant);
        vm.expectRevert(SubscriptionBilling.NotDue.selector);
        billing.charge(alice);

        vm.warp(start + 2 * PERIOD);
        vm.prank(merchant);
        billing.charge(alice);
        assertEq(_paidUntil(alice), start + 3 * PERIOD);
        assertEq(_balance(alice), 2 ether);
    }

    function testHiddenCatchUpChargesOnePeriodPerCall() public {
        vm.prank(alice);
        billing.subscribe{value: 10 ether}();

        // Three and a half periods pass without a charge: periods 2, 3 and 4 are billable.
        vm.warp(start + 3 * PERIOD + PERIOD / 2);
        vm.startPrank(merchant);
        billing.charge(alice);
        billing.charge(alice);
        billing.charge(alice);
        vm.expectRevert(SubscriptionBilling.NotDue.selector);
        billing.charge(alice);
        vm.stopPrank();

        assertEq(_paidUntil(alice), start + 4 * PERIOD);
        assertEq(billing.merchantBalance(), 4 ether);
        assertEq(_balance(alice), 6 ether);
        assertTrue(billing.isPaid(alice));
    }

    function testHiddenInsufficientBalanceThenTopUp() public {
        vm.prank(alice);
        billing.subscribe{value: 1.5 ether}();
        vm.warp(start + PERIOD);

        vm.prank(merchant);
        vm.expectRevert(SubscriptionBilling.InsufficientBalance.selector);
        billing.charge(alice);
        assertEq(_balance(alice), 0.5 ether);
        assertEq(_paidUntil(alice), start + PERIOD);

        vm.prank(alice);
        billing.topUp{value: 0.5 ether}();
        vm.prank(merchant);
        billing.charge(alice);
        assertEq(_balance(alice), 0);
        assertEq(billing.merchantBalance(), 2 ether);
    }

    function testHiddenTopUpZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(SubscriptionBilling.ZeroAmount.selector);
        billing.topUp{value: 0}();
    }

    function testHiddenOnlyMerchantChargesAndCollects() public {
        vm.prank(alice);
        billing.subscribe{value: 5 ether}();
        vm.warp(start + PERIOD);

        vm.prank(bob);
        vm.expectRevert(SubscriptionBilling.NotMerchant.selector);
        billing.charge(alice);
        vm.prank(alice);
        vm.expectRevert(SubscriptionBilling.NotMerchant.selector);
        billing.collect();
        assertEq(address(billing).balance, 5 ether);
    }

    function testHiddenCancelAuthorization() public {
        vm.prank(alice);
        billing.subscribe{value: 5 ether}();

        vm.prank(bob);
        vm.expectRevert(SubscriptionBilling.NotAuthorized.selector);
        billing.cancel(alice);

        vm.prank(merchant);
        billing.cancel(alice);
        (, , bool active) = billing.subscriptions(alice);
        assertFalse(active);

        vm.prank(alice);
        vm.expectRevert(SubscriptionBilling.NotSubscribed.selector);
        billing.cancel(alice);
    }

    function testHiddenNoChargeAfterCancel() public {
        vm.prank(alice);
        billing.subscribe{value: 5 ether}();
        vm.prank(alice);
        billing.cancel(alice);

        vm.warp(start + 5 * PERIOD);
        vm.prank(merchant);
        vm.expectRevert(SubscriptionBilling.NotSubscribed.selector);
        billing.charge(alice);

        vm.prank(alice);
        billing.withdraw();
        assertEq(alice.balance, 99 ether);
        assertEq(billing.merchantBalance(), 1 ether);
    }

    function testHiddenCannotWithdrawWhileActive() public {
        vm.prank(alice);
        billing.subscribe{value: 5 ether}();
        vm.prank(alice);
        vm.expectRevert(SubscriptionBilling.StillSubscribed.selector);
        billing.withdraw();

        vm.prank(bob);
        vm.expectRevert(SubscriptionBilling.NothingToWithdraw.selector);
        billing.withdraw();
    }

    function testHiddenResubscribeUsesLeftoverBalance() public {
        vm.prank(alice);
        billing.subscribe{value: 3 ether}();
        vm.prank(alice);
        billing.cancel(alice);

        vm.warp(start + 100 days);
        // 2 ether are still on balance, so no new ETH is needed.
        vm.prank(alice);
        billing.subscribe{value: 0}();
        assertEq(_balance(alice), 1 ether);
        assertEq(_paidUntil(alice), start + 100 days + PERIOD);
        assertEq(billing.merchantBalance(), 2 ether);
        assertTrue(billing.isPaid(alice));
    }

    function testHiddenTopUpWithoutSubscriptionIsWithdrawable() public {
        vm.prank(bob);
        billing.topUp{value: 2 ether}();
        vm.prank(merchant);
        vm.expectRevert(SubscriptionBilling.NotSubscribed.selector);
        billing.charge(bob);

        vm.prank(bob);
        billing.withdraw();
        assertEq(bob.balance, 100 ether);
    }

    function testHiddenAccountingIsExact() public {
        vm.prank(alice);
        billing.subscribe{value: 4 ether}();
        vm.prank(bob);
        billing.subscribe{value: 2 ether}();
        vm.warp(start + PERIOD);
        vm.startPrank(merchant);
        billing.charge(alice);
        billing.charge(bob);
        billing.collect();
        vm.expectRevert(SubscriptionBilling.NothingToWithdraw.selector);
        billing.collect();
        vm.stopPrank();

        assertEq(merchant.balance, 4 ether);
        assertEq(address(billing).balance, _balance(alice) + _balance(bob));
        assertEq(_balance(alice), 2 ether);
        assertEq(_balance(bob), 0);

        vm.prank(alice);
        billing.cancel(alice);
        vm.prank(alice);
        billing.withdraw();
        assertEq(address(billing).balance, 0);
    }
}
