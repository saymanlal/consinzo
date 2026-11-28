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

/// Seller contract that tries to withdraw again while it is being paid.
contract ReentrantSeller {
    NftMarketplace public market;
    uint256 public attempts;
    uint256 public successfulReentries;

    constructor(NftMarketplace market_) {
        market = market_;
    }

    function listToken(address nft, uint256 tokenId, uint256 price) external returns (uint256) {
        MockNFT(nft).approve(address(market), tokenId);
        return market.list(nft, tokenId, price);
    }

    function pull() external {
        market.withdraw();
    }

    receive() external payable {
        if (attempts < 3) {
            attempts += 1;
            (bool ok,) = address(market).call(abi.encodeWithSelector(NftMarketplace.withdraw.selector));
            if (ok) successfulReentries += 1;
        }
    }
}

/// Seller contract that cannot receive ETH.
contract RejectingSeller {
    NftMarketplace public market;

    constructor(NftMarketplace market_) {
        market = market_;
    }

    function listToken(address nft, uint256 tokenId, uint256 price) external returns (uint256) {
        MockNFT(nft).approve(address(market), tokenId);
        return market.list(nft, tokenId, price);
    }

    function pull() external {
        market.withdraw();
    }
}

/// NFT whose transferFrom calls back into the marketplace to buy the same listing again.
contract CallbackNFT is IERC721 {
    mapping(uint256 => address) internal _owners;
    NftMarketplace public market;
    uint256 public targetListing;
    bool public armed;
    bool public reentrySucceeded;

    function mint(address to, uint256 tokenId) external {
        _owners[tokenId] = to;
    }

    function arm(NftMarketplace market_, uint256 listingId) external payable {
        market = market_;
        targetListing = listingId;
        armed = true;
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        return _owners[tokenId];
    }

    function transferFrom(address from, address to, uint256 tokenId) external override {
        require(_owners[tokenId] == from, "WRONG_FROM");
        _owners[tokenId] = to;
        if (armed) {
            armed = false;
            (bool ok,) = address(market).call{value: address(this).balance}(
                abi.encodeWithSelector(NftMarketplace.buy.selector, targetListing)
            );
            if (ok) reentrySucceeded = true;
        }
    }

    receive() external payable {}
}

contract NftMarketplaceHiddenTest is Test {
    NftMarketplace public market;
    MockNFT public nft;
    address public seller = address(0x5E11E4);
    address public buyer = address(0xB0B);
    address public carol = address(0xCA401);
    address public treasury = address(0xFEE);
    address public treasury2 = address(0xFEE2);

    function setUp() public {
        market = new NftMarketplace(250, treasury);
        nft = new MockNFT();
        for (uint256 i = 1; i <= 4; ++i) {
            nft.mint(seller, i);
        }
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
        vm.deal(buyer, 100 ether);
        vm.deal(carol, 100 ether);
    }

    function _list(uint256 tokenId, uint256 price) internal returns (uint256 id) {
        vm.prank(seller);
        id = market.list(address(nft), tokenId, price);
    }

    function _solvent() internal view {
        assertEq(address(market).balance, market.totalPending());
    }

    function testHiddenConstructorValidation() public {
        vm.expectRevert(NftMarketplace.FeeTooHigh.selector);
        new NftMarketplace(1001, address(0));

        vm.expectRevert(NftMarketplace.ZeroAddress.selector);
        new NftMarketplace(1000, address(0));

        NftMarketplace m = new NftMarketplace(1000, treasury);
        assertEq(uint256(m.feeBps()), 1000);
        assertEq(m.owner(), address(this));
        assertEq(m.feeRecipient(), treasury);
    }

    function testHiddenSetFeeAccessAndValidation() public {
        vm.prank(seller);
        vm.expectRevert(NftMarketplace.NotOwner.selector);
        market.setFee(5000, address(0));

        vm.expectRevert(NftMarketplace.FeeTooHigh.selector);
        market.setFee(1001, treasury2);

        vm.expectRevert(NftMarketplace.ZeroAddress.selector);
        market.setFee(100, address(0));

        market.setFee(0, treasury2);
        assertEq(uint256(market.feeBps()), 0);
        assertEq(market.feeRecipient(), treasury2);
    }

    function testHiddenListValidation() public {
        vm.prank(seller);
        vm.expectRevert(NftMarketplace.ZeroAddress.selector);
        market.list(address(0), 1, 0);

        vm.prank(seller);
        vm.expectRevert(NftMarketplace.ZeroPrice.selector);
        market.list(address(nft), 1, 0);

        vm.prank(buyer);
        vm.expectRevert(NftMarketplace.NotTokenOwner.selector);
        market.list(address(nft), 1, 1 ether);

        assertEq(market.listingCount(), 0);
        assertEq(nft.ownerOf(1), seller);
    }

    function testHiddenListRequiresApproval() public {
        nft.mint(carol, 50);
        vm.prank(carol);
        vm.expectRevert();
        market.list(address(nft), 50, 1 ether);
        assertEq(nft.ownerOf(50), carol);
    }

    function testHiddenListedTokenCannotBeListedAgain() public {
        _list(1, 1 ether);
        vm.prank(seller);
        vm.expectRevert(NftMarketplace.NotTokenOwner.selector);
        market.list(address(nft), 1, 2 ether);
    }

    function testHiddenUpdatePriceRules() public {
        uint256 id = _list(1, 1 ether);

        vm.prank(buyer);
        vm.expectRevert(NftMarketplace.NotSeller.selector);
        market.updatePrice(id, 1);

        vm.prank(seller);
        vm.expectRevert(NftMarketplace.ZeroPrice.selector);
        market.updatePrice(id, 0);

        vm.prank(seller);
        vm.expectRevert(NftMarketplace.ListingNotActive.selector);
        market.updatePrice(99, 1 ether);

        vm.prank(seller);
        market.updatePrice(id, 3 ether);

        vm.prank(buyer);
        vm.expectRevert(NftMarketplace.InsufficientPayment.selector);
        market.buy{value: 1 ether}(id);

        vm.prank(buyer);
        market.buy{value: 3 ether}(id);
        assertEq(market.pendingWithdrawals(seller), 2.925 ether);
        assertEq(market.pendingWithdrawals(treasury), 0.075 ether);

        vm.prank(seller);
        vm.expectRevert(NftMarketplace.ListingNotActive.selector);
        market.updatePrice(id, 5 ether);
        _solvent();
    }

    function testHiddenCancelRules() public {
        uint256 id = _list(1, 1 ether);

        vm.prank(buyer);
        vm.expectRevert(NftMarketplace.NotSeller.selector);
        market.cancel(id);

        vm.prank(seller);
        vm.expectRevert(NftMarketplace.ListingNotActive.selector);
        market.cancel(0);

        vm.prank(seller);
        market.cancel(id);

        vm.prank(seller);
        vm.expectRevert(NftMarketplace.ListingNotActive.selector);
        market.cancel(id);

        // a cancelled token can be listed again under a new id
        uint256 id2 = _list(1, 2 ether);
        assertEq(id2, 2);
        assertEq(nft.ownerOf(1), address(market));
    }

    function testHiddenCannotBuyTwiceOrOwnListing() public {
        uint256 id = _list(1, 1 ether);

        vm.deal(seller, 5 ether);
        vm.prank(seller);
        vm.expectRevert(NftMarketplace.SelfPurchase.selector);
        market.buy{value: 1 ether}(id);

        vm.prank(buyer);
        market.buy{value: 1 ether}(id);

        vm.prank(carol);
        vm.expectRevert(NftMarketplace.ListingNotActive.selector);
        market.buy{value: 1 ether}(id);

        vm.prank(seller);
        vm.expectRevert(NftMarketplace.ListingNotActive.selector);
        market.cancel(id);

        assertEq(nft.ownerOf(1), buyer);
        assertEq(market.totalPending(), 1 ether);
        _solvent();
    }

    function testHiddenFeeIsSnapshottedAtListing() public {
        uint256 idOld = _list(1, 10 ether);
        market.setFee(1000, treasury2); // owner raises the fee after the listing exists
        uint256 idNew = _list(2, 10 ether);

        vm.prank(buyer);
        market.buy{value: 10 ether}(idOld);
        // old rate (2.5%), but paid to the recipient configured at purchase time
        assertEq(market.pendingWithdrawals(treasury2), 0.25 ether);
        assertEq(market.pendingWithdrawals(treasury), 0);
        assertEq(market.pendingWithdrawals(seller), 9.75 ether);

        vm.prank(buyer);
        market.buy{value: 10 ether}(idNew);
        assertEq(market.pendingWithdrawals(treasury2), 1.25 ether);
        assertEq(market.pendingWithdrawals(seller), 18.75 ether);
        _solvent();
    }

    function testHiddenFeeRoundsDownAndZeroFee() public {
        uint256 id = _list(1, 399); // 399 * 250 / 10000 = 9.975 -> 9
        vm.prank(buyer);
        market.buy{value: 399}(id);
        assertEq(market.pendingWithdrawals(treasury), 9);
        assertEq(market.pendingWithdrawals(seller), 390);

        uint256 id2 = _list(2, 39); // fee rounds to zero
        vm.prank(buyer);
        market.buy{value: 39}(id2);
        assertEq(market.pendingWithdrawals(treasury), 9);
        assertEq(market.pendingWithdrawals(seller), 429);

        market.setFee(0, treasury);
        uint256 id3 = _list(3, 1 ether);
        vm.prank(buyer);
        market.buy{value: 1 ether}(id3);
        assertEq(market.pendingWithdrawals(treasury), 9);
        assertEq(market.pendingWithdrawals(seller), 1 ether + 429);
        _solvent();
    }

    function testHiddenSolvencyAcrossManyTrades() public {
        uint256 a = _list(1, 1 ether);
        uint256 b = _list(2, 2 ether);
        uint256 c = _list(3, 3 ether);
        uint256 d = _list(4, 4 ether);

        vm.prank(buyer);
        market.buy{value: 1.5 ether}(a);
        _solvent();
        vm.prank(carol);
        market.buy{value: 2 ether}(b);
        _solvent();
        vm.prank(seller);
        market.cancel(c);
        _solvent();

        vm.prank(seller);
        market.withdraw();
        assertEq(seller.balance, 2.925 ether);
        _solvent();

        vm.prank(buyer);
        market.buy{value: 7 ether}(d);
        _solvent();

        vm.prank(buyer);
        market.withdraw(); // 0.5 + 3 overpaid
        assertEq(buyer.balance, 100 ether - 1 ether - 4 ether);
        vm.prank(treasury);
        market.withdraw();
        assertEq(treasury.balance, 0.175 ether);
        vm.prank(seller);
        market.withdraw();
        assertEq(seller.balance, 2.925 ether + 3.9 ether);

        assertEq(market.totalPending(), 0);
        assertEq(address(market).balance, 0);

        vm.prank(carol);
        vm.expectRevert(NftMarketplace.NothingToWithdraw.selector);
        market.withdraw();
    }

    function testHiddenWithdrawReentrancyPaysOnce() public {
        ReentrantSeller rs = new ReentrantSeller(market);
        nft.mint(address(rs), 100);
        uint256 id = rs.listToken(address(nft), 100, 4 ether);

        // other users' funds sit in the marketplace and must not be drained
        uint256 other = _list(1, 10 ether);
        vm.prank(carol);
        market.buy{value: 10 ether}(other);

        vm.prank(buyer);
        market.buy{value: 4 ether}(id);

        rs.pull();
        assertEq(rs.successfulReentries(), 0);
        assertGt(rs.attempts(), 0);
        assertEq(address(rs).balance, 3.9 ether);
        assertEq(market.pendingWithdrawals(address(rs)), 0);
        assertEq(address(market).balance, 10.1 ether);
        _solvent();
    }

    function testHiddenRejectingSellerCannotBlockSale() public {
        RejectingSeller bad = new RejectingSeller(market);
        nft.mint(address(bad), 200);
        uint256 id = bad.listToken(address(nft), 200, 2 ether);

        vm.prank(buyer);
        market.buy{value: 2 ether}(id); // the sale itself never sends ETH to the seller
        assertEq(nft.ownerOf(200), buyer);

        vm.expectRevert(NftMarketplace.TransferFailed.selector);
        bad.pull();
        assertEq(market.pendingWithdrawals(address(bad)), 1.95 ether); // credit is preserved

        vm.prank(treasury);
        market.withdraw(); // others are unaffected
        assertEq(treasury.balance, 0.05 ether);
        _solvent();
    }

    function testHiddenListingClosedBeforeTokenTransfer() public {
        CallbackNFT evil = new CallbackNFT();
        evil.mint(seller, 7);
        vm.prank(seller);
        uint256 id = market.list(address(evil), 7, 1 ether);

        evil.arm{value: 1 ether}(market, id);
        vm.prank(buyer);
        market.buy{value: 1 ether}(id);

        assertFalse(evil.reentrySucceeded());
        assertEq(evil.ownerOf(7), buyer);
        assertEq(market.pendingWithdrawals(seller), 0.975 ether);
        assertEq(market.totalPending(), 1 ether);
        _solvent();
    }
}
