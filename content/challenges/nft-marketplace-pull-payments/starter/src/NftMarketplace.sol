// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Subset of ERC-721 used by the marketplace.
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract NftMarketplace {
    uint16 public constant MAX_FEE_BPS = 1000; // 10%

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
        // TODO: validate (FeeTooHigh, then ZeroAddress)
        feeBps = feeBps_;
        feeRecipient = feeRecipient_;
    }

    function setFee(uint16 newFeeBps, address newFeeRecipient) external {
        // TODO: owner only, same validation as the constructor, emit FeeUpdated
        revert("NOT_IMPLEMENTED");
    }

    function list(address nft, uint256 tokenId, uint256 price) external returns (uint256 listingId) {
        // TODO: validate (ZeroAddress, ZeroPrice, NotTokenOwner)
        // TODO: store the listing with the current feeBps, escrow the token, emit Listed
        revert("NOT_IMPLEMENTED");
    }

    function updatePrice(uint256 listingId, uint256 newPrice) external {
        // TODO: ListingNotActive, NotSeller, ZeroPrice
        revert("NOT_IMPLEMENTED");
    }

    function cancel(uint256 listingId) external {
        // TODO: ListingNotActive, NotSeller; deactivate, return the token
        revert("NOT_IMPLEMENTED");
    }

    function buy(uint256 listingId) external payable {
        // TODO: ListingNotActive, SelfPurchase, InsufficientPayment
        // TODO: deactivate the listing, credit fee / seller proceeds / buyer overpayment
        // TODO: transfer the token to the buyer
        revert("NOT_IMPLEMENTED");
    }

    function withdraw() external {
        // TODO: pay out pendingWithdrawals[msg.sender] (NothingToWithdraw, TransferFailed)
        revert("NOT_IMPLEMENTED");
    }
}
