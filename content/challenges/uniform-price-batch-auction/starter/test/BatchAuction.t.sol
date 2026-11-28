// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BatchAuction.sol";

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

contract BatchAuctionTest is Test {
    BatchAuction public auction;
    MockERC20 public base;
    MockERC20 public quote;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);
    address public dave = address(0xDA7E);
    address public erin = address(0xE21);
    address public frank = address(0xF2A);
    uint256 internal constant START = 1_000_000;
    uint256 internal constant DEADLINE = 1_700_000_000 + 1 hours;

    function setUp() public {
        base = new MockERC20("BASE");
        quote = new MockERC20("QUOTE");
        auction = new BatchAuction(IToken(address(base)), IToken(address(quote)), DEADLINE);
        address[6] memory users = [alice, bob, carol, dave, erin, frank];
        for (uint256 i = 0; i < 6; i++) {
            base.mint(users[i], START);
            quote.mint(users[i], START);
            vm.prank(users[i]);
            base.approve(address(auction), type(uint256).max);
            vm.prank(users[i]);
            quote.approve(address(auction), type(uint256).max);
        }
    }

    function _bid(address who, uint256 price, uint256 amount) internal returns (uint256 id) {
        vm.prank(who);
        id = auction.submitBid(price, amount);
    }

    function _ask(address who, uint256 price, uint256 amount) internal returns (uint256 id) {
        vm.prank(who);
        id = auction.submitAsk(price, amount);
    }

    function _clear() internal {
        vm.warp(DEADLINE);
        auction.clear();
    }

    function _filled(uint256 id) internal view returns (uint256 f) {
        (, , , , f, ) = auction.orders(id);
    }

    function _claimAll() internal {
        uint256 n = auction.orderCount();
        for (uint256 i = 0; i < n; i++) {
            (, , , , , bool claimed) = auction.orders(i);
            if (!claimed) auction.claim(i);
        }
    }

    function testSubmitEscrowsFunds() public {
        assertEq(_bid(bob, 50, 10), 0);
        assertEq(_ask(alice, 44, 8), 1);
        assertEq(auction.orderCount(), 2);
        assertEq(quote.balanceOf(address(auction)), 500);
        assertEq(base.balanceOf(address(auction)), 8);
        (address owner, bool isBid, uint256 price, uint256 amount, uint256 filled, bool claimed) = auction.orders(0);
        assertEq(owner, bob);
        assertTrue(isBid);
        assertEq(price, 50);
        assertEq(amount, 10);
        assertEq(filled, 0);
        assertFalse(claimed);
    }

    // bids 10@50, 10@48, 10@45; asks 8@44, 12@47, 10@49.
    // Volume is 20 at both 47 and 48 with zero imbalance: the lower price wins.
    function _balancedBook() internal {
        _bid(bob, 50, 10); // 0
        _bid(carol, 48, 10); // 1
        _bid(dave, 45, 10); // 2
        _ask(alice, 44, 8); // 3
        _ask(erin, 47, 12); // 4
        _ask(frank, 49, 10); // 5
    }

    function testClearingPriceMaximisesVolume() public {
        _balancedBook();
        _clear();
        assertTrue(auction.cleared());
        assertEq(auction.clearingPrice(), 47);
        assertEq(auction.clearedVolume(), 20);
        assertEq(_filled(0), 10);
        assertEq(_filled(1), 10);
        assertEq(_filled(2), 0);
        assertEq(_filled(3), 8);
        assertEq(_filled(4), 12);
        assertEq(_filled(5), 0);
    }

    function testEveryoneSettlesAtTheUniformPrice() public {
        _balancedBook();
        _clear();
        _claimAll();
        // buyers pay 47 although they bid 50 and 48
        assertEq(base.balanceOf(bob), START + 10);
        assertEq(quote.balanceOf(bob), START - 470);
        assertEq(quote.balanceOf(carol), START - 470);
        assertEq(quote.balanceOf(dave), START);
        assertEq(base.balanceOf(dave), START);
        // sellers receive 47 although they asked 44 and 47
        assertEq(quote.balanceOf(alice), START + 376);
        assertEq(base.balanceOf(alice), START - 8);
        assertEq(quote.balanceOf(erin), START + 564);
        assertEq(base.balanceOf(frank), START);
        assertEq(base.balanceOf(address(auction)), 0);
        assertEq(quote.balanceOf(address(auction)), 0);
    }

    function testExcessDemandIsRationedByPriceThenTime() public {
        _bid(bob, 50, 10); // 0
        _bid(carol, 50, 10); // 1
        _bid(dave, 52, 5); // 2
        _ask(alice, 48, 12); // 3
        _clear();
        // 12 trade at 48 and at 50 with the same imbalance: lowest price
        assertEq(auction.clearingPrice(), 48);
        assertEq(auction.clearedVolume(), 12);
        assertEq(_filled(2), 5); // best price first
        assertEq(_filled(0), 7); // then the earlier of the two bids at 50
        assertEq(_filled(1), 0);
        (uint256 baseOut, uint256 quoteOut) = auction.claim(0);
        assertEq(baseOut, 7);
        assertEq(quoteOut, 500 - 7 * 48);
        (baseOut, quoteOut) = auction.claim(3);
        assertEq(baseOut, 0);
        assertEq(quoteOut, 576);
    }

    function testNoCrossMeansFullRefunds() public {
        _bid(bob, 40, 10);
        _ask(alice, 50, 10);
        _clear();
        assertEq(auction.clearingPrice(), 0);
        assertEq(auction.clearedVolume(), 0);
        _claimAll();
        assertEq(quote.balanceOf(bob), START);
        assertEq(base.balanceOf(alice), START);
    }

    function testPhasesAreEnforced() public {
        _bid(bob, 40, 10);
        vm.expectRevert(BatchAuction.AuctionStillOpen.selector);
        auction.clear();
        vm.expectRevert(BatchAuction.NotCleared.selector);
        auction.claim(0);
        vm.warp(DEADLINE);
        vm.prank(alice);
        vm.expectRevert(BatchAuction.AuctionClosed.selector);
        auction.submitAsk(40, 10);
        auction.clear();
        vm.expectRevert(BatchAuction.AlreadyCleared.selector);
        auction.clear();
    }
}
