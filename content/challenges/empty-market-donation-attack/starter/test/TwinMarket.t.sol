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

contract TwinMarketTest is MarketFixture {
    function setUp() public {
        _deploy();
    }

    function testDonationDoesNotMoveExchangeRate() public {
        _inflateEmptyMarket(1000e18);
        assertEq(market.sharesOf(0, attacker), 2);
        assertEq(market.cash(0), 2);
        assertEq(market.exchangeRate(0), 1e18);
        assertEq(market.collateralValue(attacker), 1);
    }

    function testEmptyMarketDonationCannotBackABorrow() public {
        _inflateEmptyMarket(1000e18);
        vm.prank(attacker);
        vm.expectRevert(TwinMarket.Undercollateralized.selector);
        market.borrow(1, 370e18);
        assertEq(b.balanceOf(address(market)), 1000e18);
    }

    function testRedeemUnderlyingRoundsSharesUp() public {
        vm.prank(borrower);
        market.mint(0, 1000e18);
        vm.prank(borrower);
        market.borrow(1, 100e18);
        // Market 1: 900 cash + 101 owed over 1000 shares.
        assertEq(market.exchangeRate(1), 1.001e18);
        vm.prank(lp);
        uint256 burned = market.redeemUnderlying(1, 10);
        assertEq(burned, 10);
        assertEq(market.sharesOf(1, lp), 1000e18 - 10);
    }

    function testSupplyBorrowRepayRedeem() public {
        vm.prank(borrower);
        market.mint(0, 1000e18);
        vm.prank(borrower);
        market.borrow(1, 100e18);
        assertEq(market.debtValue(borrower), 101e18);
        vm.prank(borrower);
        uint256 repaid = market.repay(1, 500e18);
        assertEq(repaid, 101e18);
        assertEq(market.debtValue(borrower), 0);

        vm.prank(lp);
        uint256 out = market.redeem(1, 1000e18);
        assertEq(out, 1001e18);
        assertEq(b.balanceOf(lp), 10_001e18);
    }

    function testBorrowLimitIsSeventyFivePercent() public {
        vm.prank(borrower);
        market.mint(0, 100e18);
        vm.prank(borrower);
        vm.expectRevert(TwinMarket.Undercollateralized.selector);
        market.borrow(1, 75e18);
        vm.prank(borrower);
        market.borrow(1, 74e18);
    }
}
