// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Subset of ERC-721 used by the marketplace.
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract NftMarketplace {
    uint16 public constant MAX_FEE_BPS = 1000; // 10%
    uint256 internal constant BPS = 10_000;

    struct Listing {
        address seller;
        address nft;
        uint256 tokenId;
        uint256 price;
        uint16 feeBps; // fee rate captured when the listing was created
        bool active;
    }

    address public immutable owner;
    uint16 public feeBps;
    address public feeRecipient;

    uint256 public listingCount;
    mapping(uint256 => Listing) public listings;

    mapping(address => uint256) public pendingWithdrawals;
    uint256 public totalPending;

    event Listed(uint256 indexed listingId, address indexed seller, address indexed nft, uint256 tokenId, uint256 price);
    event PriceUpdated(uint256 indexed listingId, uint256 newPrice);
    event Cancelled(uint256 indexed listingId);
    event Sold(uint256 indexed listingId, address indexed buyer, uint256 price, uint256 fee);
    event Withdrawn(address indexed account, uint256 amount);
    event FeeUpdated(uint16 feeBps, address feeRecipient);

    error NotOwner();
    error ZeroAddress();
    error FeeTooHigh();
    error ZeroPrice();
    error NotTokenOwner();
    error ListingNotActive();
    error NotSeller();
    error SelfPurchase();
    error InsufficientPayment();
    error NothingToWithdraw();
    error TransferFailed();

    constructor(uint16 feeBps_, address feeRecipient_) {
        owner = msg.sender;
        _setFee(feeBps_, feeRecipient_);
    }

    // ------------------------------------------------------------------ configuration

    function setFee(uint16 newFeeBps, address newFeeRecipient) external {
        if (msg.sender != owner) revert NotOwner();
        _setFee(newFeeBps, newFeeRecipient);
    }

    function _setFee(uint16 newFeeBps, address newFeeRecipient) internal {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        feeBps = newFeeBps;
        feeRecipient = newFeeRecipient;
        emit FeeUpdated(newFeeBps, newFeeRecipient);
    }

    // ------------------------------------------------------------------ listings

    function list(address nft, uint256 tokenId, uint256 price) external returns (uint256 listingId) {
        if (nft == address(0)) revert ZeroAddress();
        if (price == 0) revert ZeroPrice();
        if (IERC721(nft).ownerOf(tokenId) != msg.sender) revert NotTokenOwner();

        listingId = ++listingCount;
        listings[listingId] = Listing({
            seller: msg.sender,
            nft: nft,
            tokenId: tokenId,
            price: price,
            feeBps: feeBps,
            active: true
        });

        // Escrow: the marketplace holds the token while it is listed, so a listing can
        // never point at a token the seller has since moved.
        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);

        emit Listed(listingId, msg.sender, nft, tokenId, price);
    }

    function updatePrice(uint256 listingId, uint256 newPrice) external {
        Listing storage l = listings[listingId];
        if (!l.active) revert ListingNotActive();
        if (l.seller != msg.sender) revert NotSeller();
        if (newPrice == 0) revert ZeroPrice();
        l.price = newPrice;
        emit PriceUpdated(listingId, newPrice);
    }

    function cancel(uint256 listingId) external {
        Listing storage l = listings[listingId];
        if (!l.active) revert ListingNotActive();
        if (l.seller != msg.sender) revert NotSeller();

        l.active = false;
        IERC721(l.nft).transferFrom(address(this), msg.sender, l.tokenId);

        emit Cancelled(listingId);
    }

    // ------------------------------------------------------------------ trading

    function buy(uint256 listingId) external payable {
        Listing storage l = listings[listingId];
        if (!l.active) revert ListingNotActive();
        if (l.seller == msg.sender) revert SelfPurchase();

        uint256 price = l.price;
        if (msg.value < price) revert InsufficientPayment();

        // Effects first: the listing is closed before the NFT contract is called.
        l.active = false;

        uint256 fee = (price * l.feeBps) / BPS;
        _credit(feeRecipient, fee);
        _credit(l.seller, price - fee);
        _credit(msg.sender, msg.value - price);

        IERC721(l.nft).transferFrom(address(this), msg.sender, l.tokenId);

        emit Sold(listingId, msg.sender, price, fee);
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // Clear the balance before sending so a re-entering recipient finds nothing.
        pendingWithdrawals[msg.sender] = 0;
        totalPending -= amount;

        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function _credit(address account, uint256 amount) internal {
        if (amount == 0) return;
        pendingWithdrawals[account] += amount;
        totalPending += amount;
    }
}
