// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NftOrderBook.sol";

contract MockNFT {
    mapping(uint256 => address) public ownerOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    function mint(address to, uint256 id) external {
        ownerOf[id] = to;
    }

    function setApprovalForAll(address op, bool ok) external {
        isApprovedForAll[msg.sender][op] = ok;
    }

    function transferFrom(address from, address to, uint256 id) external {
        require(ownerOf[id] == from, "NOT_OWNER");
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_APPROVED");
        ownerOf[id] = to;
    }
}

contract NftOrderBookHiddenTest is Test {
    NftOrderBook internal book;
    MockNFT internal nft;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA401);
    address internal mallory = address(0xBAD);

    function setUp() public {
        book = new NftOrderBook();
        nft = new MockNFT();
        nft.mint(alice, 1);
        nft.mint(alice, 2);
        nft.mint(carol, 3);
        vm.prank(alice);
        nft.setApprovalForAll(address(book), true);
        vm.prank(carol);
        nft.setApprovalForAll(address(book), true);
        vm.deal(bob, 100 ether);
        vm.deal(mallory, 100 ether);
    }

    function _list(address maker, uint256 tokenId, uint256 price) internal returns (uint256 id) {
        vm.prank(maker);
        id = book.createOrder(address(nft), tokenId, price);
    }

    function testHiddenUnknownOrderReverts() public {
        vm.prank(bob);
        vm.expectRevert(NftOrderBook.OrderNotOpen.selector);
        book.fillOrder{value: 1 ether}(77);
        assertTrue(book.orderStatus(77) == NftOrderBook.Status.None);
    }

    function testHiddenRepeatedFillAtStalePriceBlocked() public {
        uint256 id = _list(alice, 1, 1 ether);
        vm.prank(bob);
        book.fillOrder{value: 1 ether}(id);
        // Alice buys the token back for much more through a new listing by Bob.
        vm.prank(bob);
        nft.setApprovalForAll(address(book), true);
        uint256 id2 = _list(bob, 1, 30 ether);
        vm.deal(alice, 30 ether);
        vm.prank(alice);
        book.fillOrder{value: 30 ether}(id2);
        assertEq(nft.ownerOf(1), alice);

        vm.prank(mallory);
        vm.expectRevert(NftOrderBook.OrderNotOpen.selector);
        book.fillOrder{value: 1 ether}(id);
        assertEq(nft.ownerOf(1), alice);
        assertEq(mallory.balance, 100 ether);
    }

    function testHiddenCancelRules() public {
        uint256 id = _list(alice, 1, 1 ether);
        vm.prank(mallory);
        vm.expectRevert(NftOrderBook.NotMaker.selector);
        book.cancelOrder(id);
        vm.prank(alice);
        book.cancelOrder(id);
        assertTrue(book.orderStatus(id) == NftOrderBook.Status.Cancelled);
        vm.prank(alice);
        vm.expectRevert(NftOrderBook.OrderNotOpen.selector);
        book.cancelOrder(id);
    }

    function testHiddenFilledOrderCannotBeCancelled() public {
        uint256 id = _list(alice, 1, 1 ether);
        vm.prank(bob);
        book.fillOrder{value: 1 ether}(id);
        vm.prank(alice);
        vm.expectRevert(NftOrderBook.OrderNotOpen.selector);
        book.cancelOrder(id);
        assertTrue(book.orderStatus(id) == NftOrderBook.Status.Filled);
    }

    function testHiddenOrdersAfterCancelAllAreFillable() public {
        uint256 oldId = _list(alice, 1, 1 ether);
        vm.prank(alice);
        book.cancelAllOrders();
        uint256 newId = _list(alice, 1, 2 ether);

        vm.prank(bob);
        vm.expectRevert(NftOrderBook.StaleNonce.selector);
        book.fillOrder{value: 1 ether}(oldId);
        vm.prank(bob);
        book.fillOrder{value: 2 ether}(newId);
        assertEq(nft.ownerOf(1), bob);
        assertEq(alice.balance, 2 ether);
    }

    function testHiddenCancelAllDoesNotAffectOtherMakers() public {
        uint256 carolId = _list(carol, 3, 1 ether);
        vm.prank(alice);
        book.cancelAllOrders();
        vm.prank(alice);
        book.cancelAllOrders();
        assertEq(book.nonces(alice), 2);
        assertEq(book.nonces(carol), 0);
        vm.prank(bob);
        book.fillOrder{value: 1 ether}(carolId);
        assertEq(nft.ownerOf(3), bob);
    }

    function testHiddenWrongPriceAndCheckOrder() public {
        uint256 id = _list(alice, 1, 1 ether);
        vm.prank(bob);
        vm.expectRevert(NftOrderBook.WrongPrice.selector);
        book.fillOrder{value: 0.5 ether}(id);
        vm.prank(bob);
        vm.expectRevert(NftOrderBook.WrongPrice.selector);
        book.fillOrder{value: 2 ether}(id);
        // A cancelled order reports OrderNotOpen even when the price is also wrong.
        vm.prank(alice);
        book.cancelOrder(id);
        vm.prank(bob);
        vm.expectRevert(NftOrderBook.OrderNotOpen.selector);
        book.fillOrder{value: 0.5 ether}(id);
    }

    function testHiddenCreateRules() public {
        vm.prank(mallory);
        vm.expectRevert(NftOrderBook.NotMaker.selector);
        book.createOrder(address(nft), 1, 1 ether);
        vm.prank(alice);
        vm.expectRevert(NftOrderBook.ZeroPrice.selector);
        book.createOrder(address(nft), 1, 0);
    }
}
