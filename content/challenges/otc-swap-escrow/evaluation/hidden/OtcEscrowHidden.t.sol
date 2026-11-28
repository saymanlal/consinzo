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

contract OtcEscrowHiddenTest is Test {
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    OtcEscrow public escrow;
    address public maker = address(0xA11CE);
    address public maker2 = address(0xD00D);
    address public taker = address(0xB0B);

    function setUp() public {
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        escrow = new OtcEscrow();
        tokenA.mint(maker, 1_000 ether);
        tokenA.mint(maker2, 1_000 ether);
        tokenB.mint(taker, 1_000 ether);
        vm.prank(maker);
        tokenA.approve(address(escrow), type(uint256).max);
        vm.prank(maker2);
        tokenA.approve(address(escrow), type(uint256).max);
        vm.prank(taker);
        tokenB.approve(address(escrow), type(uint256).max);
    }

    function _create(address who, uint256 sellAmount, uint256 buyAmount) internal returns (uint256 id) {
        vm.prank(who);
        id = escrow.createOrder(address(tokenA), address(tokenB), sellAmount, buyAmount);
    }

    function testHiddenTakerPaymentRoundsUp() public {
        uint256 id = _create(maker, 3, 10);
        assertEq(escrow.quote(id, 1), 4);
        assertEq(escrow.quote(id, 2), 7);
        assertEq(escrow.quote(id, 3), 10);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(taker);
            assertEq(escrow.fill(id, 1), 4);
        }
        // splitting never makes the maker receive less than the asked total
        assertEq(tokenB.balanceOf(maker), 12);
        assertEq(tokenA.balanceOf(taker), 3);
        (, , , , , uint256 remaining, bool active) = escrow.orders(id);
        assertEq(remaining, 0);
        assertFalse(active);
    }

    function testHiddenPriceDoesNotDriftAfterPartialFill() public {
        uint256 id = _create(maker, 90 ether, 30 ether);
        vm.prank(taker);
        escrow.fill(id, 89 ether);
        // still 3 A per B, quoted from the original amounts
        assertEq(escrow.quote(id, 1 ether), 333333333333333334);
        vm.prank(taker);
        assertEq(escrow.fill(id, 0.6 ether), 0.2 ether);
        (, , , uint256 sa, uint256 ba, uint256 remaining, bool active) = escrow.orders(id);
        assertEq(sa, 90 ether);
        assertEq(ba, 30 ether);
        assertEq(remaining, 0.4 ether);
        assertTrue(active);
    }

    function testHiddenFillRevertOrder() public {
        vm.prank(taker);
        vm.expectRevert(OtcEscrow.OrderNotActive.selector);
        escrow.fill(0, 0); // never created; inactive wins over zero amount
        uint256 id = _create(maker, 10 ether, 10 ether);
        vm.prank(taker);
        vm.expectRevert(OtcEscrow.ZeroAmount.selector);
        escrow.fill(id, 0);
        vm.prank(taker);
        vm.expectRevert(OtcEscrow.ExceedsRemaining.selector);
        escrow.fill(id, 10 ether + 1);
        vm.prank(taker);
        escrow.fill(id, 4 ether);
        vm.prank(taker);
        vm.expectRevert(OtcEscrow.ExceedsRemaining.selector);
        escrow.fill(id, 6 ether + 1);
        vm.prank(taker);
        escrow.fill(id, 6 ether);
        vm.prank(taker);
        vm.expectRevert(OtcEscrow.OrderNotActive.selector);
        escrow.fill(id, 1);
        // a filled order cannot be cancelled; the inactive check comes before the maker check
        vm.prank(taker);
        vm.expectRevert(OtcEscrow.OrderNotActive.selector);
        escrow.cancel(id);
        vm.prank(maker);
        vm.expectRevert(OtcEscrow.OrderNotActive.selector);
        escrow.cancel(id);
    }

    function testHiddenCreateValidation() public {
        vm.startPrank(maker);
        vm.expectRevert(OtcEscrow.InvalidTokens.selector);
        escrow.createOrder(address(tokenA), address(tokenA), 1 ether, 1 ether);
        vm.expectRevert(OtcEscrow.InvalidTokens.selector);
        escrow.createOrder(address(0), address(tokenB), 1 ether, 1 ether);
        vm.expectRevert(OtcEscrow.InvalidTokens.selector);
        escrow.createOrder(address(tokenA), address(0), 1 ether, 1 ether);
        vm.expectRevert(OtcEscrow.ZeroAmount.selector);
        escrow.createOrder(address(tokenA), address(tokenB), 0, 1 ether);
        vm.expectRevert(OtcEscrow.ZeroAmount.selector);
        escrow.createOrder(address(tokenA), address(tokenB), 1 ether, 0);
        vm.stopPrank();
        assertEq(escrow.nextOrderId(), 0);
    }

    function testHiddenOrdersAreIsolated() public {
        uint256 a = _create(maker, 100 ether, 100 ether);
        uint256 b = _create(maker2, 50 ether, 200 ether);
        assertEq(b, 1);
        vm.prank(maker);
        vm.expectRevert(OtcEscrow.NotMaker.selector);
        escrow.cancel(b);
        vm.prank(taker);
        escrow.fill(b, 20 ether); // pays 80 B to maker2
        vm.prank(maker);
        assertEq(escrow.cancel(a), 100 ether);
        vm.prank(maker);
        vm.expectRevert(OtcEscrow.OrderNotActive.selector);
        escrow.cancel(a);
        // order b's escrow is untouched by cancelling a
        assertEq(tokenA.balanceOf(address(escrow)), 30 ether);
        vm.prank(taker);
        vm.expectRevert(OtcEscrow.ExceedsRemaining.selector);
        escrow.fill(b, 31 ether);
        vm.prank(maker2);
        assertEq(escrow.cancel(b), 30 ether);
        assertEq(tokenA.balanceOf(address(escrow)), 0);
        assertEq(tokenA.balanceOf(maker), 1_000 ether);
        assertEq(tokenA.balanceOf(maker2), 980 ether);
        assertEq(tokenB.balanceOf(maker2), 80 ether);
        assertEq(tokenB.balanceOf(maker), 0);
    }

    function testHiddenFailedPaymentLeavesOrderUntouched() public {
        uint256 id = _create(maker, 10 ether, 5_000 ether);
        // taker only owns 1000 B: the payment for the whole order fails
        vm.prank(taker);
        vm.expectRevert();
        escrow.fill(id, 10 ether);
        (, , , , , uint256 remaining, bool active) = escrow.orders(id);
        assertEq(remaining, 10 ether);
        assertTrue(active);
        vm.prank(taker);
        assertEq(escrow.fill(id, 2 ether), 1_000 ether);
        assertEq(tokenB.balanceOf(taker), 0);
        assertEq(tokenB.balanceOf(address(escrow)), 0);
    }
}
