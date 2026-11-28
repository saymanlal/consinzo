// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/IsolatedMarket.sol";

/// @dev Minimal ERC-20 used only by the tests.
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract IsolatedMarketTest is Test {
    MockERC20 internal asset;
    MockERC20 internal coll;
    IsolatedMarket internal market;

    address internal alice = address(0xA11CE); // supplier
    address internal bob = address(0xB0B); // borrower
    address internal liq = address(0x11C); // liquidator

    function setUp() public {
        asset = new MockERC20();
        coll = new MockERC20();
        market = _deploy(0);
    }

    function _deploy(uint256 rate) internal returns (IsolatedMarket m) {
        m = new IsolatedMarket(address(asset), address(coll), 0.8e18, rate, 1.1e18);
        m.setPrice(2000e18);
        asset.mint(alice, 100_000e18);
        asset.mint(liq, 100_000e18);
        coll.mint(bob, 10e18);
        vm.prank(alice);
        asset.approve(address(m), type(uint256).max);
        vm.prank(liq);
        asset.approve(address(m), type(uint256).max);
        vm.startPrank(bob);
        asset.approve(address(m), type(uint256).max);
        coll.approve(address(m), type(uint256).max);
        vm.stopPrank();
    }

    /// alice supplies 10,000; bob posts 1 collateral (worth 2,000) and borrows 1,600.
    function _open(IsolatedMarket m) internal {
        vm.prank(alice);
        m.supply(10_000e18);
        vm.prank(bob);
        m.depositCollateral(1e18);
        vm.prank(bob);
        m.borrow(1600e18);
    }

    function testSupplyAndWithdraw() public {
        vm.prank(alice);
        uint256 shares = market.supply(10_000e18);
        assertEq(shares, 10_000e18);
        assertEq(market.supplyShares(alice), 10_000e18);
        assertEq(market.totalSupplyAssets(), 10_000e18);
        assertEq(asset.balanceOf(address(market)), 10_000e18);

        vm.prank(alice);
        uint256 assets = market.withdraw(4_000e18);
        assertEq(assets, 4_000e18);
        assertEq(market.totalSupplyShares(), 6_000e18);
        assertEq(asset.balanceOf(alice), 94_000e18);
    }

    function testBorrowUpToLltv() public {
        _open(market);
        assertEq(market.borrowShares(bob), 1600e18);
        assertEq(market.debtOf(bob), 1600e18);
        assertEq(market.totalBorrowAssets(), 1600e18);
        assertEq(asset.balanceOf(bob), 1600e18);
        assertTrue(market.isHealthy(bob));

        vm.prank(bob);
        vm.expectRevert(IsolatedMarket.PositionUnhealthy.selector);
        market.borrow(1);
    }

    function testRepayReducesDebt() public {
        _open(market);
        vm.prank(bob);
        uint256 paid = market.repay(bob, 600e18);
        assertEq(paid, 600e18);
        assertEq(market.debtOf(bob), 1000e18);
        assertEq(market.totalBorrowAssets(), 1000e18);
        assertEq(asset.balanceOf(address(market)), 9_000e18);
    }

    function testInterestAccruesToSuppliers() public {
        IsolatedMarket m = _deploy(1e10); // 1e-8 per second
        vm.prank(alice);
        m.supply(10_000e18);
        vm.prank(bob);
        m.depositCollateral(1e18);
        vm.prank(bob);
        m.borrow(1000e18);

        vm.warp(block.timestamp + 1_000_000);
        m.accrue();
        // 1000 * 1e-8 * 1e6 = 10
        assertEq(m.totalBorrowAssets(), 1010e18);
        assertEq(m.totalSupplyAssets(), 10_010e18);
        assertEq(m.debtOf(bob), 1010e18);
        assertEq(m.totalBorrowShares(), 1000e18);
        assertEq(m.totalSupplyShares(), 10_000e18);
    }

    function testHealthyPositionCannotBeLiquidated() public {
        _open(market);
        vm.prank(liq);
        vm.expectRevert(IsolatedMarket.PositionHealthy.selector);
        market.liquidate(bob, 0.1e18);
    }

    function testLiquidationPaysBonus() public {
        _open(market);
        market.setPrice(1800e18); // max borrow 1440 < 1600
        assertFalse(market.isHealthy(bob));

        vm.prank(liq);
        uint256 repaid = market.liquidate(bob, 0.55e18);
        // 0.55 * 1800 = 990 of collateral for 990 / 1.1 = 900 of debt
        assertEq(repaid, 900e18);
        assertEq(coll.balanceOf(liq), 0.55e18);
        assertEq(asset.balanceOf(liq), 100_000e18 - 900e18);
        assertEq(market.collateralOf(bob), 0.45e18);
        assertEq(market.debtOf(bob), 700e18);
        assertEq(market.totalSupplyAssets(), 10_000e18);
    }

    function testBadDebtIsSocialised() public {
        _open(market);
        market.setPrice(1100e18);

        vm.prank(liq);
        uint256 repaid = market.liquidate(bob, 1e18);
        // all collateral (worth 1100) for 1000 of debt; the other 600 is unrecoverable
        assertEq(repaid, 1000e18);
        assertEq(market.collateralOf(bob), 0);
        assertEq(market.borrowShares(bob), 0);
        assertEq(market.totalBorrowAssets(), 0);
        assertEq(market.totalBorrowShares(), 0);
        assertEq(market.totalSupplyAssets(), 9_400e18);

        vm.prank(alice);
        uint256 assets = market.withdraw(10_000e18);
        assertEq(assets, 9_400e18);
        assertEq(asset.balanceOf(address(market)), 0);
    }
}
