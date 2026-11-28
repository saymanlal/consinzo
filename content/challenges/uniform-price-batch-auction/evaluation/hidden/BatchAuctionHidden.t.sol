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

contract BatchAuctionHiddenTest is Test {
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

    function testHiddenExcessSupplyIsRationedByPriceThenTime() public {
        _ask(alice, 40, 10); // 0
        _ask(erin, 40, 10); // 1
        _ask(frank, 38, 10); // 2
        _bid(bob, 45, 15); // 3
        _clear();
        // 38: volume 10. 40 and 45: volume 15, imbalance 15 -> lowest price 40
        assertEq(auction.clearingPrice(), 40);
        assertEq(auction.clearedVolume(), 15);
        assertEq(_filled(2), 10);
        assertEq(_filled(0), 5);
        assertEq(_filled(1), 0);
        _claimAll();
        assertEq(quote.balanceOf(frank), START + 400);
        assertEq(quote.balanceOf(alice), START + 200);
        assertEq(base.balanceOf(alice), START - 5);
        assertEq(base.balanceOf(erin), START);
        assertEq(base.balanceOf(bob), START + 15);
        assertEq(quote.balanceOf(bob), START - 600);
        assertEq(base.balanceOf(address(auction)), 0);
        assertEq(quote.balanceOf(address(auction)), 0);
    }

    function testHiddenSmallerImbalanceBreaksVolumeTie() public {
        _bid(bob, 50, 10); // 0
        _bid(carol, 46, 10); // 1
        _ask(alice, 45, 10); // 2
        _ask(erin, 48, 5); // 3
        _clear();
        // volume is 10 at 45, 46, 48 and 50; imbalance is 10, 10, 5, 5
        assertEq(auction.clearingPrice(), 48);
        assertEq(auction.clearedVolume(), 10);
        assertEq(_filled(0), 10);
        assertEq(_filled(1), 0);
        assertEq(_filled(2), 10);
        assertEq(_filled(3), 0);
        _claimAll();
        assertEq(quote.balanceOf(alice), START + 480);
        assertEq(quote.balanceOf(bob), START - 480);
    }

    function testHiddenHigherVolumeBeatsEverything() public {
        _bid(bob, 100, 1); // 0
        _bid(carol, 60, 30); // 1
        _ask(alice, 10, 1); // 2
        _ask(erin, 55, 40); // 3
        _clear();
        // at 55 and 60: demand 31, supply 41 -> volume 31
        assertEq(auction.clearingPrice(), 55);
        assertEq(auction.clearedVolume(), 31);
        assertEq(_filled(0), 1);
        assertEq(_filled(1), 30);
        assertEq(_filled(2), 1);
        assertEq(_filled(3), 30);
        _claimAll();
        assertEq(base.balanceOf(erin), START - 30);
        assertEq(quote.balanceOf(erin), START + 30 * 55);
        assertEq(quote.balanceOf(alice), START + 55);
        assertEq(quote.balanceOf(bob), START - 55);
        assertEq(quote.balanceOf(address(auction)), 0);
        assertEq(base.balanceOf(address(auction)), 0);
    }

    function testHiddenSubmissionOrderDoesNotChangeThePrice() public {
        _ask(frank, 49, 10); // 0
        _bid(dave, 45, 10); // 1
        _ask(erin, 47, 12); // 2
        _bid(carol, 48, 10); // 3
        _ask(alice, 44, 8); // 4
        _bid(bob, 50, 10); // 5
        _clear();
        assertEq(auction.clearingPrice(), 47);
        assertEq(auction.clearedVolume(), 20);
        assertEq(_filled(5), 10);
        assertEq(_filled(3), 10);
        assertEq(_filled(1), 0);
        assertEq(_filled(4), 8);
        assertEq(_filled(2), 12);
        assertEq(_filled(0), 0);
    }

    function testHiddenCancelBeforeDeadline() public {
        _bid(bob, 50, 10); // 0
        _bid(carol, 50, 10); // 1
        _ask(alice, 50, 10); // 2
        vm.prank(carol);
        vm.expectRevert(BatchAuction.NotOrderOwner.selector);
        auction.cancel(0);
        vm.prank(bob);
        auction.cancel(0);
        assertEq(quote.balanceOf(bob), START);
        vm.prank(bob);
        vm.expectRevert(BatchAuction.AlreadyClaimed.selector);
        auction.cancel(0);
        (, , , uint256 amount, , bool claimed) = auction.orders(0);
        assertEq(amount, 0);
        assertTrue(claimed);

        _clear();
        // the cancelled bid takes no part: carol is filled
        assertEq(auction.clearedVolume(), 10);
        assertEq(_filled(0), 0);
        assertEq(_filled(1), 10);
        vm.expectRevert(BatchAuction.AlreadyClaimed.selector);
        auction.claim(0);
        _claimAll();
        assertEq(quote.balanceOf(address(auction)), 0);
        assertEq(base.balanceOf(address(auction)), 0);
    }

    function testHiddenCancelledPriceIsNotACandidate() public {
        _bid(bob, 60, 10); // 0
        _ask(alice, 50, 10); // 1
        uint256 id = _ask(erin, 40, 10); // 2, would make 40 the lowest tie candidate
        vm.prank(erin);
        auction.cancel(id);
        _clear();
        assertEq(auction.clearingPrice(), 50);
        assertEq(auction.clearedVolume(), 10);
    }

    function testHiddenCannotCancelAfterDeadline() public {
        _bid(bob, 50, 10);
        vm.warp(DEADLINE);
        vm.prank(bob);
        vm.expectRevert(BatchAuction.AuctionClosed.selector);
        auction.cancel(0);
        vm.warp(DEADLINE - 1);
        vm.prank(bob);
        auction.cancel(0);
    }

    function testHiddenClaimPaysOwnerOnceOnly() public {
        _bid(bob, 50, 10);
        _ask(alice, 50, 10);
        _clear();
        vm.prank(frank); // anyone may trigger the claim
        (uint256 baseOut, uint256 quoteOut) = auction.claim(0);
        assertEq(baseOut, 10);
        assertEq(quoteOut, 0);
        assertEq(base.balanceOf(bob), START + 10);
        assertEq(base.balanceOf(frank), START);
        vm.expectRevert(BatchAuction.AlreadyClaimed.selector);
        auction.claim(0);
        vm.prank(alice);
        auction.claim(1);
        assertEq(quote.balanceOf(alice), START + 500);
    }

    function testHiddenInvalidOrdersAndCapacity() public {
        vm.startPrank(bob);
        vm.expectRevert(BatchAuction.InvalidOrder.selector);
        auction.submitBid(0, 10);
        vm.expectRevert(BatchAuction.InvalidOrder.selector);
        auction.submitAsk(10, 0);
        for (uint256 i = 0; i < 40; i++) {
            auction.submitBid(1 + i, 1);
        }
        vm.expectRevert(BatchAuction.TooManyOrders.selector);
        auction.submitBid(1, 1);
        vm.expectRevert(BatchAuction.TooManyOrders.selector);
        auction.submitAsk(1, 1);
        vm.stopPrank();
        assertEq(auction.orderCount(), 40);
    }

    function testHiddenFullBookClears() public {
        // 20 bids 1 @ 101..120 and 20 asks 1 @ 91..110
        for (uint256 i = 1; i <= 20; i++) {
            _bid(bob, 100 + i, 1);
            _ask(alice, 90 + i, 1);
        }
        _clear();
        // at p in 101..110: demand = 121 - p, supply = p - 90; they meet between 105 and 106
        // volume 15 at both, imbalance 1 at both -> 105
        assertEq(auction.clearingPrice(), 105);
        assertEq(auction.clearedVolume(), 15);
        _claimAll();
        assertEq(base.balanceOf(bob), START + 15);
        // all 20 bids were escrowed and refunded down to 15 * 105
        assertEq(quote.balanceOf(bob), START - 15 * 105);
        assertEq(quote.balanceOf(alice), START + 15 * 105);
        assertEq(base.balanceOf(alice), START - 15);
        // the five highest-priced bids of the 20 are filled first, the five lowest are not
        assertEq(_filled(0), 0); // bid @101
        assertEq(_filled(38), 1); // bid @120
        assertEq(_filled(1), 1); // ask @91
        assertEq(_filled(39), 0); // ask @110
    }
}
