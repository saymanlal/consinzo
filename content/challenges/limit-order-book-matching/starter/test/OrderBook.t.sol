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

contract OrderBookTest is Test {
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

    function testRestingOrdersEscrowFunds() public {
        (uint256 askId, uint256 f1) = _sell(alice, 50, 100);
        (uint256 bidId, uint256 f2) = _buy(bob, 40, 100);
        assertEq(askId, 1);
        assertEq(bidId, 2);
        assertEq(f1 + f2, 0);
        assertEq(book.bestAsk(), 1);
        assertEq(book.bestBid(), 2);
        assertEq(base.balanceOf(address(book)), 100);
        assertEq(quote.balanceOf(address(book)), 4000);
        (address owner, bool isBuy, uint256 price, uint256 remaining, , ) = book.orders(2);
        assertEq(owner, bob);
        assertTrue(isBuy);
        assertEq(price, 40);
        assertEq(remaining, 100);
    }

    function testBookIsSortedByPrice() public {
        _sell(alice, 52, 10); // 1
        _sell(alice, 50, 10); // 2
        _sell(alice, 51, 10); // 3
        assertEq(book.bestAsk(), 2);
        assertEq(_next(2), 3);
        assertEq(_next(3), 1);
        assertEq(_next(1), 0);

        _buy(bob, 40, 10); // 4
        _buy(bob, 42, 10); // 5
        _buy(bob, 41, 10); // 6
        assertEq(book.bestBid(), 5);
        assertEq(_next(5), 6);
        assertEq(_next(6), 4);
        assertEq(_prev(4), 6);
        assertEq(_prev(5), 0);
    }

    function testTakerPaysMakerPrice() public {
        _sell(alice, 50, 100);
        (uint256 id, uint256 filled) = _buy(bob, 55, 100);
        assertEq(id, 0); // nothing rests
        assertEq(filled, 100);
        assertEq(quote.balanceOf(bob), START - 5000);
        assertEq(base.balanceOf(bob), START + 100);
        assertEq(quote.balanceOf(alice), START + 5000);
        assertEq(base.balanceOf(alice), START - 100);
        assertEq(book.bestAsk(), 0);
        assertEq(base.balanceOf(address(book)), 0);
        assertEq(quote.balanceOf(address(book)), 0);
    }

    function testTimePriorityAtEqualPrice() public {
        _sell(alice, 50, 60); // 1
        _sell(carol, 50, 60); // 2
        (, uint256 filled) = _buy(bob, 50, 100);
        assertEq(filled, 100);
        assertEq(quote.balanceOf(alice), START + 3000);
        assertEq(quote.balanceOf(carol), START + 2000);
        assertEq(book.bestAsk(), 2);
        assertEq(_remaining(2), 20);
        (address gone, , , , , ) = book.orders(1);
        assertEq(gone, address(0));
    }

    function testPartialFillRestsRemainder() public {
        _sell(alice, 50, 30); // 1
        (uint256 id, uint256 filled) = _buy(bob, 50, 100);
        assertEq(filled, 30);
        assertEq(id, 2);
        assertEq(_remaining(2), 70);
        assertEq(book.bestBid(), 2);
        assertEq(book.bestAsk(), 0);
        assertEq(quote.balanceOf(address(book)), 3500);
        assertEq(quote.balanceOf(bob), START - 1500 - 3500);
    }

    function testCancelRefundsEscrow() public {
        _buy(bob, 40, 100);
        vm.prank(alice);
        vm.expectRevert(OrderBook.NotOrderOwner.selector);
        book.cancelOrder(1);
        vm.prank(bob);
        book.cancelOrder(1);
        assertEq(quote.balanceOf(bob), START);
        assertEq(book.bestBid(), 0);
    }
}
