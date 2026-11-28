// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OtcEscrow.sol";

contract MockERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

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
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract OtcEscrowTest is Test {
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    OtcEscrow public escrow;
    address public maker = address(0xA11CE);
    address public taker = address(0xB0B);
    address public taker2 = address(0xCA201);

    function setUp() public {
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        escrow = new OtcEscrow();
        tokenA.mint(maker, 1_000 ether);
        tokenB.mint(taker, 1_000 ether);
        tokenB.mint(taker2, 1_000 ether);
        vm.prank(maker);
        tokenA.approve(address(escrow), type(uint256).max);
        vm.prank(taker);
        tokenB.approve(address(escrow), type(uint256).max);
        vm.prank(taker2);
        tokenB.approve(address(escrow), type(uint256).max);
    }

    function _create(uint256 sellAmount, uint256 buyAmount) internal returns (uint256 id) {
        vm.prank(maker);
        id = escrow.createOrder(address(tokenA), address(tokenB), sellAmount, buyAmount);
    }

    function testCreateEscrowsSellTokens() public {
        uint256 id = _create(100 ether, 250 ether);
        assertEq(id, 0);
        assertEq(escrow.nextOrderId(), 1);
        assertEq(tokenA.balanceOf(address(escrow)), 100 ether);
        (address m, address st, address bt, uint256 sa, uint256 ba, uint256 remaining, bool active) = escrow.orders(0);
        assertEq(m, maker);
        assertEq(st, address(tokenA));
        assertEq(bt, address(tokenB));
        assertEq(sa, 100 ether);
        assertEq(ba, 250 ether);
        assertEq(remaining, 100 ether);
        assertTrue(active);
    }

    function testFullFill() public {
        uint256 id = _create(100 ether, 250 ether);
        vm.prank(taker);
        uint256 cost = escrow.fill(id, 100 ether);
        assertEq(cost, 250 ether);
        assertEq(tokenA.balanceOf(taker), 100 ether);
        assertEq(tokenB.balanceOf(maker), 250 ether);
        assertEq(tokenA.balanceOf(address(escrow)), 0);
        (, , , , , uint256 remaining, bool active) = escrow.orders(id);
        assertEq(remaining, 0);
        assertFalse(active);
    }

    function testPartialFills() public {
        uint256 id = _create(100 ether, 250 ether);
        assertEq(escrow.quote(id, 40 ether), 100 ether);
        vm.prank(taker);
        escrow.fill(id, 40 ether);
        vm.prank(taker2);
        uint256 cost = escrow.fill(id, 60 ether);
        assertEq(cost, 150 ether);
        assertEq(tokenA.balanceOf(taker), 40 ether);
        assertEq(tokenA.balanceOf(taker2), 60 ether);
        assertEq(tokenB.balanceOf(maker), 250 ether);
    }

    function testCancelReturnsRemainder() public {
        uint256 id = _create(100 ether, 250 ether);
        vm.prank(taker);
        escrow.fill(id, 30 ether);
        vm.prank(maker);
        uint256 refunded = escrow.cancel(id);
        assertEq(refunded, 70 ether);
        assertEq(tokenA.balanceOf(maker), 970 ether);
        vm.prank(taker);
        vm.expectRevert(OtcEscrow.OrderNotActive.selector);
        escrow.fill(id, 1 ether);
    }

    function testOnlyMakerCancels() public {
        uint256 id = _create(100 ether, 250 ether);
        vm.prank(taker);
        vm.expectRevert(OtcEscrow.NotMaker.selector);
        escrow.cancel(id);
    }
}
