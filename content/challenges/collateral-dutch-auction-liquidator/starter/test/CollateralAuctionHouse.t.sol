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

contract CollateralAuctionHouseTest is Test {
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

    function testStartPullsCollateralAndStoresAuction() public {
        uint256 id = house.start(user, 10 ether, 12_000 ether, 2_000 ether);
        assertEq(id, 0);
        assertEq(house.auctionCount(), 1);
        assertEq(col.balanceOf(address(house)), 10 ether);
        (address u, uint256 lot, uint256 debt, uint256 startPrice, uint256 startTime, bool active) = house.auctions(0);
        assertEq(u, user);
        assertEq(lot, 10 ether);
        assertEq(debt, 12_000 ether);
        assertEq(startPrice, 2_000 ether);
        assertEq(startTime, T0);
        assertTrue(active);
    }

    function testPriceDecaysLinearlyToFloor() public {
        house.start(user, 10 ether, 12_000 ether, 2_000 ether);
        assertEq(house.priceOf(0), 2_000 ether);
        vm.warp(T0 + 250);
        assertEq(house.priceOf(0), 1_750 ether);
        vm.warp(T0 + 500);
        assertEq(house.priceOf(0), 1_500 ether);
        vm.warp(T0 + 1000);
        assertEq(house.priceOf(0), 1_000 ether);
        vm.warp(T0 + 50_000);
        assertEq(house.priceOf(0), 1_000 ether);
    }

    function testPartialTake() public {
        house.start(user, 10 ether, 12_000 ether, 2_000 ether);
        vm.warp(T0 + 250);
        vm.prank(taker);
        (uint256 out, uint256 paid) = house.take(0, 2 ether, 1_750 ether, sink);
        assertEq(out, 2 ether);
        assertEq(paid, 3_500 ether);
        assertEq(col.balanceOf(sink), 2 ether);
        assertEq(usd.balanceOf(taker), 1_000_000 ether - 3_500 ether);
        assertEq(_lot(0), 8 ether);
        assertEq(_debt(0), 8_500 ether);
        assertTrue(_active(0));
        assertEq(house.pendingProceeds(), 3_500 ether);
    }

    function testTakeCappedByDebtRefundsUser() public {
        house.start(user, 10 ether, 12_000 ether, 2_000 ether);
        vm.warp(T0 + 250);
        vm.prank(taker);
        house.take(0, 2 ether, type(uint256).max, sink);
        vm.warp(T0 + 500);
        vm.prank(taker);
        (uint256 out, uint256 paid) = house.take(0, 100 ether, type(uint256).max, sink);
        // 8 ether at 1500 would cost 12000 > 8500: pay 8500 and receive 8500 / 1500
        assertEq(paid, 8_500 ether);
        assertEq(out, 5666666666666666666);
        assertEq(col.balanceOf(sink), 2 ether + 5666666666666666666);
        assertEq(col.balanceOf(user), 2333333333333333334);
        assertEq(col.balanceOf(address(house)), 0);
        assertEq(_lot(0), 0);
        assertEq(_debt(0), 0);
        assertFalse(_active(0));
        assertEq(house.pendingProceeds(), 12_000 ether);
        assertEq(house.totalBadDebt(), 0);
    }

    function testMaxPriceProtectsTaker() public {
        house.start(user, 10 ether, 12_000 ether, 2_000 ether);
        vm.warp(T0 + 250);
        vm.prank(taker);
        vm.expectRevert(CollateralAuctionHouse.PriceTooHigh.selector);
        house.take(0, 1 ether, 1_750 ether - 1, sink);
    }

    function testOwnerWithdrawsProceeds() public {
        house.start(user, 10 ether, 12_000 ether, 2_000 ether);
        vm.prank(taker);
        house.take(0, 1 ether, type(uint256).max, sink);
        uint256 amount = house.withdrawProceeds(address(0xBA4C));
        assertEq(amount, 2_000 ether);
        assertEq(usd.balanceOf(address(0xBA4C)), 2_000 ether);
        assertEq(house.pendingProceeds(), 0);
    }
}
