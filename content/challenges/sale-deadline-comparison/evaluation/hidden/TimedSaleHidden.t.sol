// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TimedSale.sol";

contract TimedSaleHiddenTest is Test {
    TimedSale public sale;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    uint256 public closesAt;

    receive() external payable {}

    function setUp() public {
        sale = new TimedSale(0.25 ether, 3 days);
        closesAt = sale.deadline();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testHiddenDeadlineIsDeploymentPlusDuration() public {
        assertEq(closesAt, block.timestamp + 3 days);
    }

    function testHiddenBuyClosedExactlyAtDeadline() public {
        vm.warp(closesAt);
        vm.prank(alice);
        vm.expectRevert(TimedSale.SaleClosed.selector);
        sale.buy{value: 0.25 ether}(1);
    }

    function testHiddenBuyClosedLongAfterDeadline() public {
        vm.warp(closesAt + 365 days);
        vm.prank(alice);
        vm.expectRevert(TimedSale.SaleClosed.selector);
        sale.buy{value: 0.25 ether}(1);
        assertEq(address(sale).balance, 0);
    }

    function testHiddenFinalizeRefusedWhileOpen() public {
        vm.expectRevert(TimedSale.SaleStillOpen.selector);
        sale.finalize();

        vm.warp(closesAt - 1);
        vm.expectRevert(TimedSale.SaleStillOpen.selector);
        sale.finalize();
        assertFalse(sale.finalized());
    }

    function testHiddenNoPurchasesAfterFinalize() public {
        vm.prank(alice);
        sale.buy{value: 0.5 ether}(2);

        vm.warp(closesAt);
        sale.finalize();

        // Any later instant: the sale must stay closed so no ETH gets stranded.
        vm.warp(closesAt + 1);
        vm.prank(bob);
        vm.expectRevert(TimedSale.SaleClosed.selector);
        sale.buy{value: 0.25 ether}(1);

        assertEq(sale.totalSold(), 2);
        assertEq(address(sale).balance, 0);
    }

    function testHiddenFinalizeOnlyOnceAndOnlyOwner() public {
        vm.warp(closesAt + 5);
        vm.prank(alice);
        vm.expectRevert(TimedSale.NotOwner.selector);
        sale.finalize();

        sale.finalize();
        vm.expectRevert(TimedSale.AlreadyFinalized.selector);
        sale.finalize();
    }

    function testHiddenPaymentValidationWhileOpen() public {
        vm.prank(alice);
        vm.expectRevert(TimedSale.ZeroQuantity.selector);
        sale.buy{value: 0}(0);

        vm.prank(alice);
        vm.expectRevert(TimedSale.WrongPayment.selector);
        sale.buy{value: 0.25 ether}(2);

        vm.prank(alice);
        sale.buy{value: 0.5 ether}(2);
        vm.prank(bob);
        sale.buy{value: 0.75 ether}(3);
        assertEq(sale.totalSold(), 5);
        assertEq(sale.purchased(bob), 3);
        assertEq(address(sale).balance, 1.25 ether);
    }

    function testHiddenZeroDurationSaleIsClosedImmediately() public {
        TimedSale instant = new TimedSale(1 ether, 0);
        vm.prank(alice);
        vm.expectRevert(TimedSale.SaleClosed.selector);
        instant.buy{value: 1 ether}(1);
        instant.finalize();
        assertTrue(instant.finalized());
    }
}
