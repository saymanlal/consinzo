// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BondingCurve.sol";

contract NoRefundBuyer {
    function buy(BondingCurve curve, uint256 amount) external payable {
        curve.buy{value: msg.value}(amount);
    }
}

contract BondingCurveHiddenTest is Test {
    BondingCurve public curve;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);

    function setUp() public {
        // awkward parameters so that both terms round
        curve = new BondingCurve(1_234_567_890_123_457, 98_765_432_109_877);
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(carol, 1000 ether);
    }

    function _invariant() internal view {
        assertEq(curve.reserve(), curve.reserveFor(curve.totalSupply()), "reserve invariant");
        assertEq(address(curve).balance, curve.reserve(), "eth balance");
    }

    function testHiddenPathIndependence() public {
        uint256 whole = curve.buyCost(7 ether + 777);
        uint256 spent;
        uint256[4] memory parts = [uint256(1 ether + 1), 3 ether + 333, 443, 3 ether];
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(alice);
            spent += curve.buy{value: 10 ether}(parts[i]);
            _invariant();
        }
        assertEq(spent, whole);
        assertEq(curve.totalSupply(), 7 ether + 777);
    }

    function testHiddenRoundTripIsExact() public {
        vm.prank(alice);
        uint256 cost = curve.buy{value: 50 ether}(123 ether + 456_789);
        vm.prank(alice);
        uint256 r1 = curve.sell(23 ether + 789, 0);
        _invariant();
        vm.prank(alice);
        uint256 r2 = curve.sell(100 ether + 456_000, 0);
        assertEq(r1 + r2, cost);
        assertEq(alice.balance, 1000 ether);
        assertEq(curve.totalSupply(), 0);
        assertEq(curve.reserve(), 0);
        assertEq(address(curve).balance, 0);
    }

    function testHiddenInterleavedTradesKeepInvariant() public {
        vm.prank(alice);
        curve.buy{value: 100 ether}(50 ether);
        _invariant();
        vm.prank(bob);
        curve.buy{value: 100 ether}(31 ether + 7);
        _invariant();
        vm.prank(alice);
        curve.sell(12 ether + 1, 0);
        _invariant();
        vm.prank(carol);
        curve.buy{value: 100 ether}(1);
        _invariant();
        vm.prank(bob);
        curve.sell(31 ether + 7, 0);
        _invariant();
        vm.prank(carol);
        curve.sell(1, 0);
        _invariant();
        vm.prank(alice);
        curve.sell(38 ether - 1, 0);
        _invariant();
        assertEq(curve.totalSupply(), 0);
        // nobody gained or lost ETH overall except through the order of trades
        assertEq(alice.balance + bob.balance + carol.balance, 3000 ether);
    }

    function testHiddenLaterSellerGetsLess() public {
        vm.prank(alice);
        uint256 costA = curve.buy{value: 100 ether}(10 ether);
        vm.prank(bob);
        uint256 costB = curve.buy{value: 100 ether}(10 ether);
        assertGt(costB, costA);
        // alice sells first and receives what bob paid (the top of the curve)
        vm.prank(alice);
        assertEq(curve.sell(10 ether, 0), costB);
        vm.prank(bob);
        assertEq(curve.sell(10 ether, 0), costA);
    }

    function testHiddenPaymentAndSlippageChecks() public {
        uint256 cost = curve.buyCost(5 ether);
        vm.prank(alice);
        vm.expectRevert(BondingCurve.InsufficientPayment.selector);
        curve.buy{value: cost - 1}(5 ether);
        vm.prank(alice);
        curve.buy{value: cost}(5 ether);
        assertEq(alice.balance, 1000 ether - cost);

        uint256 refund = curve.sellRefund(2 ether);
        vm.prank(alice);
        vm.expectRevert(BondingCurve.SlippageExceeded.selector);
        curve.sell(2 ether, refund + 1);
        vm.prank(alice);
        assertEq(curve.sell(2 ether, refund), refund);
        _invariant();
    }

    function testHiddenRevertPaths() public {
        vm.prank(alice);
        vm.expectRevert(BondingCurve.ZeroAmount.selector);
        curve.buy{value: 1 ether}(0);
        vm.prank(alice);
        curve.buy{value: 1 ether}(3 ether);
        vm.prank(alice);
        vm.expectRevert(BondingCurve.ZeroAmount.selector);
        curve.sell(0, 0);
        vm.prank(alice);
        vm.expectRevert(BondingCurve.InsufficientBalance.selector);
        curve.sell(3 ether + 1, 0);
        // bob holds nothing even though the supply is large enough
        vm.prank(bob);
        vm.expectRevert(BondingCurve.InsufficientBalance.selector);
        curve.sell(1 ether, 0);
        vm.expectRevert();
        curve.sellRefund(3 ether + 1);
    }

    function testHiddenFailedRefundRevertsWholeBuy() public {
        NoRefundBuyer buyer = new NoRefundBuyer();
        uint256 cost = curve.buyCost(1 ether);
        vm.expectRevert();
        buyer.buy{value: cost + 1}(curve, 1 ether);
        assertEq(curve.totalSupply(), 0);
        // exact payment needs no refund and works
        buyer.buy{value: cost}(curve, 1 ether);
        assertEq(curve.balanceOf(address(buyer)), 1 ether);
        _invariant();
    }
}
