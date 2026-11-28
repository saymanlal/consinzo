// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CollateralAuctionHouse.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
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
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract CollateralAuctionHouseHiddenTest is Test {
    MockERC20 public col;
    MockERC20 public usd;
    CollateralAuctionHouse public house;
    address public user = address(0x05E2);
    address public taker = address(0x7A4E);
    address public sink = address(0x51);
    uint256 internal constant T0 = 1_700_000_000;

    function setUp() public {
        vm.warp(T0);
        col = new MockERC20();
        usd = new MockERC20();
        house = new CollateralAuctionHouse(address(col), address(usd), 1000, 5000);
        col.mint(address(this), 1_000 ether);
        col.approve(address(house), type(uint256).max);
        usd.mint(taker, 1_000_000 ether);
        vm.prank(taker);
        usd.approve(address(house), type(uint256).max);
    }

    function _lot(uint256 id) internal view returns (uint256 lot) {
        (, lot,,,,) = house.auctions(id);
    }

    function _debt(uint256 id) internal view returns (uint256 debt) {
        (,, debt,,,) = house.auctions(id);
    }

    function _active(uint256 id) internal view returns (bool active) {
        (,,,,, active) = house.auctions(id);
    }

    function testHiddenFullSaleBelowDebtRecordsBadDebt() public {
        house.start(user, 10 ether, 12_000 ether, 2_000 ether);
        vm.warp(T0 + 1000);
        vm.prank(taker);
        (uint256 out, uint256 paid) = house.take(0, 10 ether, 1_000 ether, sink);
        assertEq(out, 10 ether);
        assertEq(paid, 10_000 ether);
        assertFalse(_active(0));
        assertEq(_lot(0), 0);
        assertEq(_debt(0), 2_000 ether);
        assertEq(house.totalBadDebt(), 2_000 ether);
        assertEq(col.balanceOf(user), 0);
        assertEq(house.pendingProceeds(), 10_000 ether);

        vm.prank(taker);
        vm.expectRevert(CollateralAuctionHouse.AuctionNotActive.selector);
        house.take(0, 1 ether, type(uint256).max, sink);
        vm.expectRevert(CollateralAuctionHouse.AuctionNotActive.selector);
        house.priceOf(0);
    }

    function testHiddenExactDebtWithWholeLotClosesCleanly() public {
        house.start(user, 10 ether, 15_000 ether, 2_000 ether);
        vm.warp(T0 + 500);
        vm.prank(taker);
        (uint256 out, uint256 paid) = house.take(0, 10 ether, type(uint256).max, sink);
        assertEq(out, 10 ether);
        assertEq(paid, 15_000 ether);
        assertFalse(_active(0));
        assertEq(house.totalBadDebt(), 0);
        assertEq(_debt(0), 0);
        assertEq(col.balanceOf(user), 0);
    }

    function testHiddenOweRoundsUp() public {
        house.start(user, 1000, 1 ether, 1.5 ether + 1);
        vm.prank(taker);
        (uint256 out, uint256 paid) = house.take(0, 3, type(uint256).max, sink);
        // 3 * (1.5e18 + 1) / 1e18 = 4.5... -> 5
        assertEq(out, 3);
        assertEq(paid, 5);
        vm.prank(taker);
        (out, paid) = house.take(0, 2, type(uint256).max, sink);
        // 2 * (1.5e18 + 1) / 1e18 = 3.000...002 -> 4
        assertEq(paid, 4);
        assertEq(_lot(0), 995);
        assertEq(_debt(0), 1 ether - 9);
        assertEq(house.pendingProceeds(), 9);
    }

    function testHiddenPriceRounding() public {
        CollateralAuctionHouse h = new CollateralAuctionHouse(address(col), address(usd), 7, 3333);
        col.approve(address(h), type(uint256).max);
        h.start(user, 1 ether, 1 ether, 1001);
        // floor = 1001 * 3333 / 10000 = 333; decay at 3s = 668 * 3 / 7 = 286
        vm.warp(T0 + 3);
        assertEq(h.priceOf(0), 715);
        vm.warp(T0 + 6);
        assertEq(h.priceOf(0), 429);
        vm.warp(T0 + 7);
        assertEq(h.priceOf(0), 333);
    }

    function testHiddenDustDebtClosesWithFullRefund() public {
        house.start(user, 1 ether, 1, 2_000 ether);
        vm.prank(taker);
        (uint256 out, uint256 paid) = house.take(0, 1 ether, type(uint256).max, sink);
        // owe is capped at 1 wei of debt, which buys 1e18 / 2000e18 = 0 collateral
        assertEq(out, 0);
        assertEq(paid, 1);
        assertFalse(_active(0));
        assertEq(col.balanceOf(user), 1 ether);
        assertEq(col.balanceOf(sink), 0);
        assertEq(house.pendingProceeds(), 1);
    }

    function testHiddenConcurrentAuctionsAreIndependent() public {
        house.start(user, 10 ether, 12_000 ether, 2_000 ether);
        vm.warp(T0 + 500);
        uint256 id = house.start(address(0xB0B), 4 ether, 1_000 ether, 400 ether);
        assertEq(id, 1);
        assertEq(house.auctionCount(), 2);
        assertEq(house.priceOf(0), 1_500 ether);
        assertEq(house.priceOf(1), 400 ether);

        vm.warp(T0 + 750);
        assertEq(house.priceOf(0), 1_250 ether);
        assertEq(house.priceOf(1), 350 ether);
        vm.startPrank(taker);
        house.take(1, 1 ether, type(uint256).max, sink); // pays 350
        house.take(0, 4 ether, type(uint256).max, sink); // pays 5000
        vm.stopPrank();
        assertEq(_lot(0), 6 ether);
        assertEq(_debt(0), 7_000 ether);
        assertEq(_lot(1), 3 ether);
        assertEq(_debt(1), 650 ether);
        assertEq(col.balanceOf(address(house)), 9 ether);
        assertEq(usd.balanceOf(address(house)), 5_350 ether);
        assertEq(house.pendingProceeds(), 5_350 ether);

        // auction 1: 3 ether at 350 costs 1050 > 650 -> pay 650, receive 650/350
        vm.prank(taker);
        (uint256 out, uint256 paid) = house.take(1, 3 ether, type(uint256).max, sink);
        assertEq(paid, 650 ether);
        assertEq(out, 1857142857142857142);
        assertEq(col.balanceOf(address(0xB0B)), 3 ether - 1857142857142857142);
        assertEq(col.balanceOf(user), 0);
        assertTrue(_active(0));
        assertFalse(_active(1));
        assertEq(col.balanceOf(address(house)), 6 ether);

        house.withdrawProceeds(address(this));
        assertEq(usd.balanceOf(address(this)), 6_000 ether);
        assertEq(usd.balanceOf(address(house)), 0);
    }

    function testHiddenAccessControl() public {
        col.mint(taker, 10 ether);
        vm.prank(taker);
        col.approve(address(house), type(uint256).max);
        vm.prank(taker);
        vm.expectRevert(CollateralAuctionHouse.NotOwner.selector);
        house.start(user, 1 ether, 1 ether, 1 ether);

        house.start(user, 1 ether, 5_000 ether, 2_000 ether);
        vm.prank(taker);
        house.take(0, 0.5 ether, type(uint256).max, sink);
        vm.prank(taker);
        vm.expectRevert(CollateralAuctionHouse.NotOwner.selector);
        house.withdrawProceeds(taker);
        assertEq(house.pendingProceeds(), 1_000 ether);
    }

    function testHiddenValidation() public {
        vm.expectRevert(CollateralAuctionHouse.InvalidConfig.selector);
        new CollateralAuctionHouse(address(col), address(usd), 0, 5000);
        vm.expectRevert(CollateralAuctionHouse.InvalidConfig.selector);
        new CollateralAuctionHouse(address(col), address(usd), 100, 10_001);

        vm.expectRevert(CollateralAuctionHouse.ZeroAmount.selector);
        house.start(user, 0, 1 ether, 1 ether);
        vm.expectRevert(CollateralAuctionHouse.ZeroAmount.selector);
        house.start(user, 1 ether, 0, 1 ether);
        vm.expectRevert(CollateralAuctionHouse.ZeroAmount.selector);
        house.start(user, 1 ether, 1 ether, 0);
        assertEq(house.auctionCount(), 0);

        vm.prank(taker);
        vm.expectRevert(CollateralAuctionHouse.AuctionNotActive.selector);
        house.take(0, 1 ether, type(uint256).max, sink);

        house.start(user, 1 ether, 1 ether, 1 ether);
        vm.prank(taker);
        vm.expectRevert(CollateralAuctionHouse.ZeroAmount.selector);
        house.take(0, 0, type(uint256).max, sink);
    }

    function testHiddenFloorAtFullBpsNeverDecays() public {
        CollateralAuctionHouse h = new CollateralAuctionHouse(address(col), address(usd), 100, 10_000);
        col.approve(address(h), type(uint256).max);
        h.start(user, 1 ether, 1 ether, 777 ether);
        vm.warp(T0 + 50);
        assertEq(h.priceOf(0), 777 ether);
        vm.warp(T0 + 500);
        assertEq(h.priceOf(0), 777 ether);
    }

    function testHiddenTakerWithoutFundsCannotTake() public {
        house.start(user, 10 ether, 12_000 ether, 2_000 ether);
        vm.prank(address(0xBAD));
        vm.expectRevert();
        house.take(0, 1 ether, type(uint256).max, address(0xBAD));
        assertEq(_lot(0), 10 ether);
        assertEq(col.balanceOf(address(0xBAD)), 0);
    }
}
