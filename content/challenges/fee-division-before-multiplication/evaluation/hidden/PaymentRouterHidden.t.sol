// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PaymentRouter.sol";

contract PaymentRouterHiddenTest is Test {
    PaymentRouter public router;
    address public treasury = address(0x7EA5);
    address public shop = address(0x5407);
    address public buyer = address(0xB0B);

    function setUp() public {
        router = new PaymentRouter(treasury, 250);
        vm.deal(buyer, 100 ether);
    }

    function testHiddenRoundingBoundary() public {
        // 39 * 250 = 9_750 < 10_000 -> 0 ; 40 * 250 = 10_000 -> 1
        assertEq(router.quoteFee(0), 0);
        assertEq(router.quoteFee(39), 0);
        assertEq(router.quoteFee(40), 1);
        assertEq(router.quoteFee(79), 1);
        assertEq(router.quoteFee(80), 2);
    }

    function testHiddenOddAmounts() public {
        assertEq(router.quoteFee(19_999), 499);
        assertEq(router.quoteFee(123_456_789), 3_086_419);
        assertEq(router.quoteFee(1 ether + 7_777), 0.025 ether + 194);
    }

    function testHiddenSplittingDoesNotAvoidFee() public {
        // 100 payments of 5_000 wei: each owes 125 wei.
        for (uint256 i = 0; i < 100; i++) {
            vm.prank(buyer);
            router.pay{value: 5_000}(shop);
        }
        assertEq(router.accruedFees(), 12_500);
        assertEq(shop.balance, 487_500);
        assertEq(address(router).balance, 12_500);
    }

    function testHiddenValueIsConserved() public {
        uint256[4] memory amounts = [uint256(1), 9_999, 54_321, 3 ether + 1];
        uint256 total;
        for (uint256 i = 0; i < amounts.length; i++) {
            vm.prank(buyer);
            router.pay{value: amounts[i]}(shop);
            total += amounts[i];
        }
        assertEq(shop.balance + router.accruedFees(), total);
        assertEq(address(router).balance, router.accruedFees());
        // 0 + 249 + 1_358 + (0.075 ether + 0)
        assertEq(router.accruedFees(), 249 + 1_358 + 0.075 ether);
    }

    function testHiddenOtherFeeRates() public {
        PaymentRouter oneBps = new PaymentRouter(treasury, 1);
        assertEq(oneBps.quoteFee(9_999), 0);
        assertEq(oneBps.quoteFee(10_000), 1);
        assertEq(oneBps.quoteFee(29_999), 2);

        PaymentRouter maxFee = new PaymentRouter(treasury, 1_000);
        assertEq(maxFee.quoteFee(9), 0);
        assertEq(maxFee.quoteFee(15), 1);
        assertEq(maxFee.quoteFee(999), 99);

        PaymentRouter free = new PaymentRouter(treasury, 0);
        assertEq(free.quoteFee(1 ether), 0);
    }

    function testHiddenTreasuryWithdrawsFees() public {
        vm.prank(buyer);
        router.pay{value: 8_888}(shop); // fee 222
        vm.prank(buyer);
        vm.expectRevert(PaymentRouter.NotTreasury.selector);
        router.withdrawFees();

        vm.prank(treasury);
        router.withdrawFees();
        assertEq(treasury.balance, 222);
        assertEq(router.accruedFees(), 0);

        vm.prank(treasury);
        vm.expectRevert(PaymentRouter.NothingToWithdraw.selector);
        router.withdrawFees();
    }

    function testHiddenInputValidation() public {
        vm.prank(buyer);
        vm.expectRevert(PaymentRouter.ZeroAmount.selector);
        router.pay{value: 0}(shop);

        vm.prank(buyer);
        vm.expectRevert(PaymentRouter.ZeroAddress.selector);
        router.pay{value: 1_000}(address(0));
    }
}
