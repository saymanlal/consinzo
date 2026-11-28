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

contract IsolatedMarketHiddenTest is Test {
    MockERC20 internal asset;
    MockERC20 internal coll;
    IsolatedMarket internal market;

    address internal alice = address(0xA11CE);
    address internal carol = address(0xCA201);
    address internal bob = address(0xB0B);
    address internal liq = address(0x11C);

    function setUp() public {
        asset = new MockERC20();
        coll = new MockERC20();
        market = _deploy(0);
    }

    function _deploy(uint256 rate) internal returns (IsolatedMarket m) {
        m = new IsolatedMarket(address(asset), address(coll), 0.8e18, rate, 1.1e18);
        m.setPrice(2000e18);
        asset.mint(alice, 100_000e18);
        asset.mint(carol, 100_000e18);
        asset.mint(liq, 100_000e18);
        coll.mint(bob, 10e18);
        address[4] memory users = [alice, carol, liq, bob];
        for (uint256 i = 0; i < 4; i++) {
            vm.startPrank(users[i]);
            asset.approve(address(m), type(uint256).max);
            coll.approve(address(m), type(uint256).max);
            vm.stopPrank();
        }
    }

    function _borrow1600(IsolatedMarket m) internal {
        vm.prank(bob);
        m.depositCollateral(1e18);
        vm.prank(bob);
        m.borrow(1600e18);
    }

    function testHiddenLossSplitProRataAcrossSuppliers() public {
        vm.prank(alice);
        market.supply(6_000e18);
        vm.prank(carol);
        market.supply(4_000e18);
        _borrow1600(market);
        market.setPrice(1100e18);
        vm.prank(liq);
        market.liquidate(bob, 1e18);

        vm.prank(alice);
        assertEq(market.withdraw(6_000e18), 5_640e18);
        vm.prank(carol);
        assertEq(market.withdraw(4_000e18), 3_760e18);
        assertEq(market.totalSupplyShares(), 0);
        assertEq(asset.balanceOf(address(market)), 0);
    }

    function testHiddenLateSupplierDoesNotInheritLoss() public {
        vm.prank(alice);
        market.supply(10_000e18);
        _borrow1600(market);
        market.setPrice(1100e18);
        vm.prank(liq);
        market.liquidate(bob, 1e18);

        // share price is now 0.94; carol buys in after the loss
        vm.prank(carol);
        uint256 shares = market.supply(940e18);
        assertEq(shares, 999999999999999999999);
        vm.prank(carol);
        assertEq(market.withdraw(shares), 939999999999999999999);
        vm.prank(alice);
        uint256 got = market.withdraw(10_000e18);
        assertGe(got, 9_400e18);
        assertLe(got, 9_400e18 + 1);
    }

    function testHiddenInterestThenBadDebt() public {
        IsolatedMarket m = _deploy(1e10);
        vm.prank(alice);
        m.supply(10_000e18);
        _borrow1600(m);
        vm.warp(block.timestamp + 1_000_000);
        m.setPrice(1100e18);

        // liquidate must accrue first: debt is 1616, not 1600
        vm.prank(liq);
        uint256 repaid = m.liquidate(bob, 1e18);
        assertEq(repaid, 1000e18);
        assertEq(m.totalBorrowAssets(), 0);
        assertEq(m.totalBorrowShares(), 0);
        // 10,000 + 16 interest - 616 written off
        assertEq(m.totalSupplyAssets(), 9_400e18);
        assertEq(asset.balanceOf(address(m)), 9_400e18);
    }

    function testHiddenNoWriteOffWhileCollateralRemains() public {
        vm.prank(alice);
        market.supply(10_000e18);
        _borrow1600(market);
        market.setPrice(1100e18);

        vm.prank(liq);
        assertEq(market.liquidate(bob, 0.999e18), 999e18);
        assertEq(market.totalSupplyAssets(), 10_000e18);
        assertEq(market.debtOf(bob), 601e18);
        assertEq(market.collateralOf(bob), 0.001e18);

        vm.prank(liq);
        assertEq(market.liquidate(bob, 0.001e18), 1e18);
        assertEq(market.totalSupplyAssets(), 9_400e18);
        assertEq(market.debtOf(bob), 0);
        assertEq(market.totalBorrowAssets(), 0);
    }

    function testHiddenLiquidationBounds() public {
        vm.prank(alice);
        market.supply(10_000e18);
        _borrow1600(market);
        market.setPrice(1999e18); // max borrow 1599.2: barely unhealthy

        vm.prank(liq);
        vm.expectRevert(IsolatedMarket.InsufficientCollateral.selector);
        market.liquidate(bob, 1e18 + 1);

        // seizing everything would repay 1817 > 1600 of debt
        vm.prank(liq);
        vm.expectRevert(IsolatedMarket.RepayExceedsDebt.selector);
        market.liquidate(bob, 1e18);

        vm.prank(liq);
        vm.expectRevert(IsolatedMarket.ZeroAmount.selector);
        market.liquidate(bob, 0);

        // 0.11 * 1999 / 1.1 = 199.9
        vm.prank(liq);
        assertEq(market.liquidate(bob, 0.11e18), 199.9e18);
        assertEq(market.debtOf(bob), 1400.1e18);
    }

    function testHiddenWithdrawLimitedByLiquidity() public {
        vm.prank(alice);
        market.supply(10_000e18);
        _borrow1600(market);

        vm.prank(alice);
        vm.expectRevert(IsolatedMarket.InsufficientLiquidity.selector);
        market.withdraw(8_400e18 + 1e9);
        vm.prank(alice);
        assertEq(market.withdraw(8_400e18), 8_400e18);

        vm.prank(alice);
        vm.expectRevert(IsolatedMarket.InsufficientShares.selector);
        market.withdraw(1_600e18 + 1);

        // nothing left to lend
        vm.prank(bob);
        market.depositCollateral(5e18);
        vm.prank(bob);
        vm.expectRevert(IsolatedMarket.InsufficientLiquidity.selector);
        market.borrow(1);
    }

    function testHiddenCollateralWithdrawKeepsHealth() public {
        vm.prank(alice);
        market.supply(10_000e18);
        vm.prank(bob);
        market.depositCollateral(2e18);
        vm.prank(bob);
        market.borrow(1600e18);

        vm.prank(bob);
        vm.expectRevert(IsolatedMarket.InsufficientCollateral.selector);
        market.withdrawCollateral(2e18 + 1);
        vm.prank(bob);
        vm.expectRevert(IsolatedMarket.PositionUnhealthy.selector);
        market.withdrawCollateral(1e18 + 1e6);
        vm.prank(bob);
        market.withdrawCollateral(1e18);
        assertEq(coll.balanceOf(bob), 9e18);
        assertEq(market.collateralOf(bob), 1e18);

        // full repayment frees the rest
        vm.prank(bob);
        market.repay(bob, 1600e18);
        vm.prank(bob);
        market.withdrawCollateral(1e18);
        assertEq(coll.balanceOf(bob), 10e18);
    }

    function testHiddenRepayRoundsUpAndThirdPartyCanRepay() public {
        IsolatedMarket m = _deploy(1e10);
        vm.prank(alice);
        m.supply(10_000e18);
        vm.prank(bob);
        m.depositCollateral(1e18);
        vm.prank(bob);
        m.borrow(1000e18);
        vm.warp(block.timestamp + 1_000_000);

        // one share is worth 1.01 wei of debt and costs 2 wei
        vm.prank(carol);
        assertEq(m.repay(bob, 1), 2);
        assertEq(m.borrowShares(bob), 1000e18 - 1);
        // _deploy minted carol a second 100,000
        assertEq(asset.balanceOf(carol), 200_000e18 - 2);

        vm.prank(carol);
        vm.expectRevert(IsolatedMarket.RepayExceedsDebt.selector);
        m.repay(bob, 1000e18);

        vm.prank(alice);
        vm.expectRevert(IsolatedMarket.InsufficientLiquidity.selector);
        m.withdraw(10_000e18);
    }

    function testHiddenSupplierEarnsInterestOnWithdraw() public {
        IsolatedMarket m = _deploy(1e10);
        vm.prank(alice);
        m.supply(10_000e18);
        vm.prank(bob);
        m.depositCollateral(1e18);
        vm.prank(bob);
        m.borrow(1000e18);
        vm.warp(block.timestamp + 1_000_000);
        asset.mint(bob, 10e18);
        vm.prank(bob);
        assertEq(m.repay(bob, 1000e18), 1010e18);
        assertEq(m.totalBorrowAssets(), 0);
        // virtual share keeps one wei behind
        vm.prank(alice);
        assertEq(m.withdraw(10_000e18), 10009999999999999999999);
        assertEq(asset.balanceOf(address(m)), 1);
    }

    function testHiddenAccessControlAndParameters() public {
        vm.prank(alice);
        vm.expectRevert(IsolatedMarket.NotOwner.selector);
        market.setPrice(1);

        vm.expectRevert(IsolatedMarket.InvalidParameter.selector);
        new IsolatedMarket(address(asset), address(coll), 1e18, 0, 1.1e18);
        vm.expectRevert(IsolatedMarket.InvalidParameter.selector);
        new IsolatedMarket(address(asset), address(coll), 0, 0, 1.1e18);
        vm.expectRevert(IsolatedMarket.InvalidParameter.selector);
        new IsolatedMarket(address(asset), address(coll), 0.8e18, 0, 1e18 - 1);

        vm.prank(alice);
        vm.expectRevert(IsolatedMarket.ZeroAmount.selector);
        market.supply(0);
        vm.prank(bob);
        vm.expectRevert(IsolatedMarket.ZeroAmount.selector);
        market.depositCollateral(0);
    }
}
