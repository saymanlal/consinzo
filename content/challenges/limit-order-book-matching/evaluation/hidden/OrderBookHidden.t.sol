// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OrderBook.sol";

contract MockERC20 {
    string public name;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory name_) {
        name = name_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function burn(address from, uint256 amount) external {
        totalSupply -= amount;
        balanceOf[from] -= amount;
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

contract OrderBookHiddenTest is Test {
    OrderBook public book;
    MockERC20 public base;
    MockERC20 public quote;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);
    address public dave = address(0xDA7E);
    uint256 internal constant START = 1_000_000;

    function setUp() public {
        base = new MockERC20("BASE");
        quote = new MockERC20("QUOTE");
        book = new OrderBook(IToken(address(base)), IToken(address(quote)));
        address[4] memory users = [alice, bob, carol, dave];
        for (uint256 i = 0; i < 4; i++) {
            base.mint(users[i], START);
            quote.mint(users[i], START);
            vm.prank(users[i]);
            base.approve(address(book), type(uint256).max);
            vm.prank(users[i]);
            quote.approve(address(book), type(uint256).max);
        }
    }

    function _sell(address who, uint256 price, uint256 amount) internal returns (uint256 id, uint256 filled) {
        vm.prank(who);
        (id, filled) = book.placeLimitOrder(false, price, amount);
    }

    function _buy(address who, uint256 price, uint256 amount) internal returns (uint256 id, uint256 filled) {
        vm.prank(who);
        (id, filled) = book.placeLimitOrder(true, price, amount);
    }

    function _remaining(uint256 id) internal view returns (uint256 r) {
        (, , , r, , ) = book.orders(id);
    }

    function _next(uint256 id) internal view returns (uint256 n) {
        (, , , , , n) = book.orders(id);
    }

    function _prev(uint256 id) internal view returns (uint256 p) {
        (, , , , p, ) = book.orders(id);
    }

    function _price(uint256 id) internal view returns (uint256 p) {
        (, , p, , , ) = book.orders(id);
    }

    function testHiddenSweepStopsAtLimitAndRests() public {
        _sell(alice, 50, 10); // 1
        _sell(carol, 51, 10); // 2
        _sell(dave, 53, 10); // 3
        (uint256 id, uint256 filled) = _buy(bob, 52, 40);
        assertEq(filled, 20);
        assertEq(id, 4);
        assertEq(quote.balanceOf(alice), START + 500);
        assertEq(quote.balanceOf(carol), START + 510);
        assertEq(quote.balanceOf(dave), START);
        assertEq(base.balanceOf(bob), START + 20);
        // 1010 paid to makers, 20 * 52 escrowed
        assertEq(quote.balanceOf(bob), START - 1010 - 1040);
        assertEq(book.bestAsk(), 3);
        assertEq(book.bestBid(), 4);
        assertEq(_price(4), 52);
        assertEq(_remaining(4), 20);
        assertEq(quote.balanceOf(address(book)), 1040);
        assertEq(base.balanceOf(address(book)), 10);
    }

    function testHiddenSellTakerWalksBids() public {
        _buy(bob, 45, 10); // 1
        _buy(carol, 44, 10); // 2
        _buy(dave, 43, 10); // 3
        (uint256 id, uint256 filled) = _sell(alice, 44, 15);
        assertEq(id, 0);
        assertEq(filled, 15);
        assertEq(quote.balanceOf(alice), START + 450 + 220);
        assertEq(base.balanceOf(alice), START - 15);
        assertEq(base.balanceOf(bob), START + 10);
        assertEq(base.balanceOf(carol), START + 5);
        assertEq(book.bestBid(), 2);
        assertEq(_remaining(2), 5);
        assertEq(_prev(2), 0);
        assertEq(_next(2), 3);
        assertEq(quote.balanceOf(address(book)), 5 * 44 + 10 * 43);
    }

    function testHiddenNoMatchWhenPricesDoNotCross() public {
        _sell(alice, 50, 10);
        (uint256 id, uint256 filled) = _buy(bob, 49, 10);
        assertEq(filled, 0);
        assertEq(id, 2);
        assertEq(book.bestAsk(), 1);
        assertEq(book.bestBid(), 2);
        (id, filled) = _sell(carol, 50, 5);
        assertEq(filled, 0);
        assertEq(id, 3);
        assertEq(_next(1), 3);
    }

    function testHiddenPartiallyFilledMakerKeepsPriority() public {
        _sell(alice, 50, 100); // 1
        _buy(bob, 50, 30);
        _sell(carol, 50, 100); // 2 (ids are only consumed by resting orders)
        assertEq(book.nextOrderId(), 3);
        assertEq(book.bestAsk(), 1);
        assertEq(_remaining(1), 70);
        (, uint256 filled) = _buy(bob, 50, 80);
        assertEq(filled, 80);
        assertEq(quote.balanceOf(alice), START + 5000);
        assertEq(quote.balanceOf(carol), START + 500);
        assertEq(book.bestAsk(), 2);
        assertEq(_remaining(2), 90);
    }

    function testHiddenEqualPriceInsertsBehindAndBetterInFront() public {
        _buy(bob, 40, 1); // 1
        _buy(carol, 40, 1); // 2
        _buy(dave, 39, 1); // 3
        _buy(alice, 40, 1); // 4: behind 1 and 2, ahead of 3
        _buy(alice, 41, 1); // 5: new head
        assertEq(book.bestBid(), 5);
        assertEq(_next(5), 1);
        assertEq(_next(1), 2);
        assertEq(_next(2), 4);
        assertEq(_next(4), 3);
        assertEq(_next(3), 0);
        assertEq(_prev(3), 4);
        assertEq(_prev(1), 5);
        // a seller hitting 40 fills in exactly that order
        (, uint256 filled) = _sell(alice, 40, 3);
        assertEq(filled, 3);
        assertEq(book.bestBid(), 4);
        assertEq(base.balanceOf(carol), START + 1);
        assertEq(base.balanceOf(dave), START);
    }

    function testHiddenCancelMiddleHeadAndTail() public {
        _sell(alice, 50, 10); // 1
        _sell(bob, 51, 10); // 2
        _sell(carol, 52, 10); // 3
        _sell(dave, 53, 10); // 4
        vm.prank(bob);
        book.cancelOrder(2);
        assertEq(_next(1), 3);
        assertEq(_prev(3), 1);
        assertEq(base.balanceOf(bob), START);
        vm.prank(alice);
        book.cancelOrder(1);
        assertEq(book.bestAsk(), 3);
        assertEq(_prev(3), 0);
        vm.prank(dave);
        book.cancelOrder(4);
        assertEq(_next(3), 0);
        assertEq(base.balanceOf(address(book)), 10);
        // cancelling twice, or cancelling a filled order, fails
        vm.prank(bob);
        vm.expectRevert(OrderBook.NotOrderOwner.selector);
        book.cancelOrder(2);
        _buy(bob, 52, 10);
        vm.prank(carol);
        vm.expectRevert(OrderBook.NotOrderOwner.selector);
        book.cancelOrder(3);
        assertEq(book.bestAsk(), 0);
        assertEq(base.balanceOf(address(book)), 0);
    }

    function testHiddenCancelAfterPartialFillRefundsRemainderOnly() public {
        _buy(bob, 40, 100); // 1, escrows 4000
        _sell(alice, 40, 25);
        vm.prank(bob);
        book.cancelOrder(1);
        assertEq(quote.balanceOf(bob), START - 1000);
        assertEq(base.balanceOf(bob), START + 25);
        assertEq(quote.balanceOf(address(book)), 0);
    }

    function testHiddenInvalidOrders() public {
        vm.startPrank(alice);
        vm.expectRevert(OrderBook.InvalidOrder.selector);
        book.placeLimitOrder(true, 0, 10);
        vm.expectRevert(OrderBook.InvalidOrder.selector);
        book.placeLimitOrder(false, 10, 0);
        vm.expectRevert(OrderBook.NotOrderOwner.selector);
        book.cancelOrder(0);
        vm.expectRevert(OrderBook.NotOrderOwner.selector);
        book.cancelOrder(99);
        vm.stopPrank();
        assertEq(book.nextOrderId(), 1);
    }

    function testHiddenBookNeverHoldsMoreOrLessThanEscrow() public {
        _sell(alice, 50, 40); // 1
        _sell(carol, 55, 40); // 2
        _buy(bob, 45, 30); // 3
        _buy(dave, 52, 60); // fills 40 @ 50, rests 20 @ 52 as 4
        _sell(carol, 45, 35); // fills 20 @ 52 (4) and 15 @ 45 (3)
        // resting: ask 2 (40 @ 55), bid 3 (15 @ 45)
        assertEq(book.bestAsk(), 2);
        assertEq(book.bestBid(), 3);
        assertEq(_remaining(3), 15);
        assertEq(base.balanceOf(address(book)), 40);
        assertEq(quote.balanceOf(address(book)), 15 * 45);
        assertEq(quote.balanceOf(carol), START + 20 * 52 + 15 * 45);
        assertEq(base.balanceOf(dave), START + 60);
        assertEq(quote.balanceOf(dave), START - 2000 - 1040);
        vm.prank(carol);
        book.cancelOrder(2);
        vm.prank(bob);
        book.cancelOrder(3);
        assertEq(base.balanceOf(address(book)), 0);
        assertEq(quote.balanceOf(address(book)), 0);
        // token supply is conserved across the four traders
        assertEq(
            base.balanceOf(alice) + base.balanceOf(bob) + base.balanceOf(carol) + base.balanceOf(dave),
            4 * START
        );
        assertEq(
            quote.balanceOf(alice) + quote.balanceOf(bob) + quote.balanceOf(carol) + quote.balanceOf(dave),
            4 * START
        );
    }

    function testHiddenTakerWithoutFundsReverts() public {
        _sell(alice, 50, 10);
        address poor = address(0xDEAD1);
        vm.prank(poor);
        vm.expectRevert();
        book.placeLimitOrder(true, 50, 10);
        assertEq(_remaining(1), 10);
        assertEq(book.bestAsk(), 1);
    }
}
