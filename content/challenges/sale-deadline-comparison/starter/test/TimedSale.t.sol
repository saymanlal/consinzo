// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TimedSale.sol";

contract TimedSaleTest is Test {
    TimedSale public sale;
    address public alice = address(0xA11CE);
    uint256 public constant PRICE = 0.1 ether;
    uint256 public constant DURATION = 7 days;

    receive() external payable {}

    function setUp() public {
        sale = new TimedSale(PRICE, DURATION);
        vm.deal(alice, 10 ether);
    }

    function testBuyBeforeDeadline() public {
        vm.prank(alice);
        sale.buy{value: 0.3 ether}(3);
        assertEq(sale.purchased(alice), 3);
        assertEq(sale.totalSold(), 3);
    }

    function testBuyInLastSecondBeforeDeadline() public {
        vm.warp(sale.deadline() - 1);
        vm.prank(alice);
        sale.buy{value: 0.1 ether}(1);
        assertEq(sale.purchased(alice), 1);
    }

    function testSaleStaysClosedAfterDeadline() public {
        vm.warp(sale.deadline() + 1);
        vm.prank(alice);
        vm.expectRevert(TimedSale.SaleClosed.selector);
        sale.buy{value: 0.1 ether}(1);
        assertEq(sale.totalSold(), 0);
    }

    function testFinalizeAtDeadline() public {
        vm.prank(alice);
        sale.buy{value: 0.5 ether}(5);

        uint256 closesAt = sale.deadline();
        vm.warp(closesAt);
        uint256 before = address(this).balance;
        sale.finalize();
        assertEq(address(this).balance - before, 0.5 ether);
        assertTrue(sale.finalized());
    }
}
