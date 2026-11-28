// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BondingCurve.sol";

contract BondingCurveTest is Test {
    BondingCurve public curve;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        // first token costs 0.001 ETH, each whole token of supply adds 0.0001 ETH
        curve = new BondingCurve(0.001 ether, 0.0001 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function testReserveFunction() public view {
        assertEq(curve.reserveFor(0), 0);
        assertEq(curve.reserveFor(10 ether), 0.015 ether);
        assertEq(curve.reserveFor(20 ether), 0.04 ether);
        assertEq(curve.currentPrice(), 0.001 ether);
    }

    function testBuyMintsAndChargesCost() public {
        assertEq(curve.buyCost(10 ether), 0.015 ether);
        vm.prank(alice);
        uint256 cost = curve.buy{value: 0.015 ether}(10 ether);
        assertEq(cost, 0.015 ether);
        assertEq(curve.balanceOf(alice), 10 ether);
        assertEq(curve.totalSupply(), 10 ether);
        assertEq(curve.reserve(), 0.015 ether);
        assertEq(address(curve).balance, 0.015 ether);
        assertEq(curve.currentPrice(), 0.002 ether);
    }

    function testSecondBuyerPaysMore() public {
        vm.prank(alice);
        curve.buy{value: 0.015 ether}(10 ether);
        assertEq(curve.buyCost(10 ether), 0.025 ether);
        vm.prank(bob);
        curve.buy{value: 0.025 ether}(10 ether);
        assertEq(curve.reserve(), 0.04 ether);
    }

    function testExcessEthIsReturned() public {
        vm.prank(alice);
        curve.buy{value: 1 ether}(10 ether);
        assertEq(alice.balance, 100 ether - 0.015 ether);
        assertEq(address(curve).balance, 0.015 ether);
    }

    function testSellReturnsReserve() public {
        vm.prank(alice);
        curve.buy{value: 0.04 ether}(20 ether);
        assertEq(curve.sellRefund(10 ether), 0.025 ether);
        vm.prank(alice);
        uint256 refund = curve.sell(10 ether, 0.025 ether);
        assertEq(refund, 0.025 ether);
        assertEq(curve.balanceOf(alice), 10 ether);
        assertEq(curve.reserve(), 0.015 ether);
        assertEq(alice.balance, 100 ether - 0.015 ether);
    }
}
