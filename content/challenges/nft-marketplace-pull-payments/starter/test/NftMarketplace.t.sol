// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NftMarketplace.sol";

contract MockNFT is IERC721 {
    mapping(uint256 => address) internal _owners;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    function mint(address to, uint256 tokenId) external {
        require(_owners[tokenId] == address(0), "MINTED");
        _owners[tokenId] = to;
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        address o = _owners[tokenId];
        require(o != address(0), "NO_TOKEN");
        return o;
    }

    function approve(address to, uint256 tokenId) external {
        require(_owners[tokenId] == msg.sender, "NOT_OWNER");
        getApproved[tokenId] = to;
    }

    function setApprovalForAll(address operator, bool ok) external {
        isApprovedForAll[msg.sender][operator] = ok;
    }

    function transferFrom(address from, address to, uint256 tokenId) external override {
        require(_owners[tokenId] == from, "WRONG_FROM");
        require(
            msg.sender == from || getApproved[tokenId] == msg.sender || isApprovedForAll[from][msg.sender],
            "NOT_APPROVED"
        );
        delete getApproved[tokenId];
        _owners[tokenId] = to;
    }
}

contract NftMarketplaceTest is Test {
    NftMarketplace public market;
    MockNFT public nft;
    address public seller = address(0x5E11E4);
    address public buyer = address(0xB0B);
    address public treasury = address(0xFEE);

    function setUp() public {
        market = new NftMarketplace(250, treasury); // 2.5%
        nft = new MockNFT();
        nft.mint(seller, 1);
        nft.mint(seller, 2);
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
        vm.deal(buyer, 100 ether);
    }

    function _list(uint256 tokenId, uint256 price) internal returns (uint256 id) {
        vm.prank(seller);
        id = market.list(address(nft), tokenId, price);
    }

    function testListEscrowsToken() public {
        uint256 id = _list(1, 10 ether);
        assertEq(id, 1);
        assertEq(market.listingCount(), 1);
        assertEq(nft.ownerOf(1), address(market));

        (address s, address n, uint256 tokenId, uint256 price, uint16 fee, bool active) = market.listings(id);
        assertEq(s, seller);
        assertEq(n, address(nft));
        assertEq(tokenId, 1);
        assertEq(price, 10 ether);
        assertEq(uint256(fee), 250);
        assertTrue(active);
    }

    function testBuySplitsPaymentIntoCredits() public {
        uint256 id = _list(1, 10 ether);
        vm.prank(buyer);
        market.buy{value: 10 ether}(id);

        assertEq(nft.ownerOf(1), buyer);
        assertEq(market.pendingWithdrawals(treasury), 0.25 ether);
        assertEq(market.pendingWithdrawals(seller), 9.75 ether);
        assertEq(market.pendingWithdrawals(buyer), 0);
        assertEq(market.totalPending(), 10 ether);
        assertEq(address(market).balance, 10 ether);
        assertEq(seller.balance, 0); // nothing is pushed

        (,,,,, bool active) = market.listings(id);
        assertFalse(active);
    }

    function testWithdrawPaysSeller() public {
        uint256 id = _list(1, 10 ether);
        vm.prank(buyer);
        market.buy{value: 10 ether}(id);

        vm.prank(seller);
        market.withdraw();
        assertEq(seller.balance, 9.75 ether);
        assertEq(market.pendingWithdrawals(seller), 0);
        assertEq(market.totalPending(), 0.25 ether);

        vm.prank(seller);
        vm.expectRevert(NftMarketplace.NothingToWithdraw.selector);
        market.withdraw();
    }

    function testCancelReturnsToken() public {
        uint256 id = _list(2, 1 ether);
        vm.prank(seller);
        market.cancel(id);
        assertEq(nft.ownerOf(2), seller);

        vm.prank(buyer);
        vm.expectRevert(NftMarketplace.ListingNotActive.selector);
        market.buy{value: 1 ether}(id);
    }

    function testUnderpaymentReverts() public {
        uint256 id = _list(1, 10 ether);
        vm.prank(buyer);
        vm.expectRevert(NftMarketplace.InsufficientPayment.selector);
        market.buy{value: 10 ether - 1}(id);
        assertEq(nft.ownerOf(1), address(market));
    }

    function testOverpaymentIsCreditedToBuyer() public {
        uint256 id = _list(1, 10 ether);
        vm.prank(buyer);
        market.buy{value: 12 ether}(id);
        assertEq(market.pendingWithdrawals(buyer), 2 ether);
        assertEq(market.totalPending(), 12 ether);

        vm.prank(buyer);
        market.withdraw();
        assertEq(buyer.balance, 90 ether);
    }
}
