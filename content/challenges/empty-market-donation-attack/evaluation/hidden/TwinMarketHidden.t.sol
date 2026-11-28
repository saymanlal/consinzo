// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TwinMarket.sol";

contract MockToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        allowance[f][msg.sender] -= a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
}

abstract contract MarketFixture is Test {
    MockToken internal a;
    MockToken internal b;
    TwinMarket internal market;
    address internal lp = address(0x1111);
    address internal borrower = address(0x2222);
    address internal attacker = address(0xBAD);

    function _deploy() internal {
        a = new MockToken();
        b = new MockToken();
        market = new TwinMarket(address(a), address(b));
        _fund(lp, 10_000e18);
        _fund(borrower, 10_000e18);
        _fund(attacker, 2_000e18);
        // Market 1 has supplier liquidity. Market 0 is freshly listed and empty.
        vm.prank(lp);
        market.mint(1, 1000e18);
    }

    function _fund(address who, uint256 amount) internal {
        a.mint(who, amount);
        b.mint(who, amount);
        vm.startPrank(who);
        a.approve(address(market), type(uint256).max);
        b.approve(address(market), type(uint256).max);
        vm.stopPrank();
    }

    /// Steps 1 and 2 of the exploit: leave 2 wei of shares, then donate.
    function _inflateEmptyMarket(uint256 donation) internal {
        vm.startPrank(attacker);
        market.mint(0, 1e18);
        market.redeem(0, 1e18 - 2);
        a.transfer(address(market), donation);
        vm.stopPrank();
    }
}

contract TwinMarketHiddenTest is MarketFixture {
    function setUp() public {
        _deploy();
    }

    function testHiddenFullChainLeavesLendersWhole() public {
        _inflateEmptyMarket(1500e18);
        vm.prank(attacker);
        vm.expectRevert(TwinMarket.Undercollateralized.selector);
        market.borrow(1, 500e18);
        // The donated tokens are not the attacker's to take back either.
        vm.prank(attacker);
        vm.expectRevert();
        market.redeemUnderlying(0, 1500e18);
        assertEq(b.balanceOf(attacker), 2_000e18);
        assertEq(market.cash(1), 1000e18);
        assertEq(market.totalBorrows(1), 0);
    }

    function testHiddenDonationToLiveMarketIsIgnored() public {
        uint256 before = market.exchangeRate(1);
        vm.prank(attacker);
        b.transfer(address(market), 777e18);
        assertEq(market.exchangeRate(1), before);
        assertEq(market.cash(1), 1000e18);
        assertEq(market.totalAssets(1), 1000e18);
        vm.prank(lp);
        assertEq(market.redeem(1, 1000e18), 1000e18);
    }

    function testHiddenOneWeiWithdrawalCostsAShare() public {
        vm.prank(borrower);
        market.mint(0, 1000e18);
        vm.prank(borrower);
        market.borrow(1, 500e18);
        // rate(1) = 1005 / 1000, so 1 wei of underlying is worth less than one share.
        uint256 sharesBefore = market.sharesOf(1, lp);
        vm.startPrank(lp);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(market.redeemUnderlying(1, 1), 1);
        }
        vm.stopPrank();
        assertEq(market.sharesOf(1, lp), sharesBefore - 5);
    }

    function testHiddenRoundingFormulaExact() public {
        vm.prank(borrower);
        market.mint(0, 1000e18);
        vm.prank(borrower);
        market.borrow(1, 300e18);
        // totalAssets(1) = 1003e18, totalShares(1) = 1000e18.
        vm.prank(lp);
        uint256 burned = market.redeemUnderlying(1, 1003);
        assertEq(burned, 1000);
        vm.prank(lp);
        burned = market.redeemUnderlying(1, 1004);
        assertEq(burned, 1001);
    }

    function testHiddenRedeemChecksHealthOnFinalState() public {
        vm.prank(borrower);
        market.mint(0, 100e18);
        vm.prank(borrower);
        market.borrow(1, 50e18); // owes 50.5, needs 67.34 of collateral
        vm.prank(borrower);
        vm.expectRevert(TwinMarket.Undercollateralized.selector);
        market.redeemUnderlying(0, 40e18);
        vm.prank(borrower);
        vm.expectRevert(TwinMarket.Undercollateralized.selector);
        market.redeem(0, 40e18);
        vm.prank(borrower);
        market.redeemUnderlying(0, 30e18);
        assertEq(market.sharesOf(0, borrower), 70e18);
        assertEq(market.cash(0), 70e18);
    }

    function testHiddenCashTracksEveryFlow() public {
        vm.prank(borrower);
        market.mint(0, 400e18);
        assertEq(market.cash(0), 400e18);
        vm.prank(borrower);
        market.borrow(1, 200e18);
        assertEq(market.cash(1), 800e18);
        assertEq(market.totalBorrows(1), 202e18);
        vm.prank(borrower);
        market.repay(1, 2e18);
        assertEq(market.cash(1), 802e18);
        assertEq(market.totalBorrows(1), 200e18);
        vm.prank(lp);
        market.redeem(1, 100e18);
        assertEq(market.cash(1), 802e18 - 100.2e18);
        assertEq(b.balanceOf(address(market)), market.cash(1));
    }

    function testHiddenGuards() public {
        vm.prank(lp);
        vm.expectRevert(TwinMarket.InvalidMarket.selector);
        market.mint(2, 1e18);
        vm.prank(lp);
        vm.expectRevert(TwinMarket.ZeroAmount.selector);
        market.redeemUnderlying(1, 0);
        vm.prank(lp);
        vm.expectRevert(TwinMarket.InsufficientShares.selector);
        market.redeem(1, 1001e18);
        vm.prank(borrower);
        market.mint(0, 5000e18);
        vm.prank(borrower);
        vm.expectRevert(TwinMarket.InsufficientCash.selector);
        market.borrow(1, 1001e18);
        vm.prank(attacker);
        vm.expectRevert(TwinMarket.InsufficientShares.selector);
        market.redeemUnderlying(0, 1e18);
    }
}
