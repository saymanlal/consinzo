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

contract NftOrderBookTest is Test {
    NftOrderBook internal book;
    MockNFT internal nft;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal mallory = address(0xBAD);

    function setUp() public {
        book = new NftOrderBook();
        nft = new MockNFT();
        nft.mint(alice, 1);
        nft.mint(alice, 2);
        vm.prank(alice);
        nft.setApprovalForAll(address(book), true);
        vm.deal(bob, 100 ether);
        vm.deal(mallory, 100 ether);
    }

    function testFillTransfersTokenAndPaysMaker() public {
        vm.prank(alice);
        uint256 id = book.createOrder(address(nft), 1, 1 ether);
        vm.prank(bob);
        book.fillOrder{value: 1 ether}(id);
        assertEq(nft.ownerOf(1), bob);
        assertEq(alice.balance, 1 ether);
        assertTrue(book.orderStatus(id) == NftOrderBook.Status.Filled);
    }

    function testCancelledOrderCannotBeFilled() public {
        vm.prank(alice);
        uint256 id = book.createOrder(address(nft), 1, 1 ether);
        vm.prank(alice);
        book.cancelOrder(id);
        vm.prank(mallory);
        vm.expectRevert(NftOrderBook.OrderNotOpen.selector);
        book.fillOrder{value: 1 ether}(id);
        assertEq(nft.ownerOf(1), alice);
    }

    function testFilledOrderCannotBeFilledAgainAfterTokenReturns() public {
        vm.prank(alice);
        uint256 id = book.createOrder(address(nft), 1, 1 ether);
        vm.prank(bob);
        book.fillOrder{value: 1 ether}(id);
        // Bob later sends the token back to Alice. Her marketplace approval is still active.
        vm.prank(bob);
        nft.transferFrom(bob, alice, 1);

        vm.prank(mallory);
        vm.expectRevert(NftOrderBook.OrderNotOpen.selector);
        book.fillOrder{value: 1 ether}(id);
        assertEq(nft.ownerOf(1), alice);
    }

    function testCancelAllInvalidatesOutstandingOrders() public {
        vm.prank(alice);
        uint256 id1 = book.createOrder(address(nft), 1, 1 ether);
        vm.prank(alice);
        uint256 id2 = book.createOrder(address(nft), 2, 2 ether);
        vm.prank(alice);
        book.cancelAllOrders();
        assertEq(book.nonces(alice), 1);

        vm.prank(mallory);
        vm.expectRevert(NftOrderBook.StaleNonce.selector);
        book.fillOrder{value: 1 ether}(id1);
        vm.prank(mallory);
        vm.expectRevert(NftOrderBook.StaleNonce.selector);
        book.fillOrder{value: 2 ether}(id2);
    }
}
