// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Minimal token interface used by the auction house. Provided; do not edit.
interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Dutch-auction liquidator for a single collateral type.
contract CollateralAuctionHouse {
    struct Auction {
        address user; // liquidated account, receives leftover collateral
        uint256 lot; // collateral still for sale
        uint256 debt; // quote still to raise
        uint256 startPrice; // WAD quote per whole collateral token
        uint256 startTime;
        bool active;
    }

    error NotOwner();
    error InvalidConfig();
    error ZeroAmount();
    error AuctionNotActive();
    error PriceTooHigh();

    event AuctionStarted(uint256 indexed id, address indexed user, uint256 lot, uint256 debt, uint256 startPrice);
    event Take(uint256 indexed id, address indexed taker, uint256 collateralOut, uint256 quoteIn, uint256 price);
    event AuctionClosed(uint256 indexed id, uint256 collateralRefund, uint256 badDebt);

    uint256 internal constant WAD = 1e18;
    uint256 internal constant BPS = 10_000;

    address public immutable owner;
    address public immutable collateral;
    address public immutable quote;
    uint256 public immutable duration;
    uint256 public immutable floorBps;

    uint256 public auctionCount;
    uint256 public pendingProceeds;
    uint256 public totalBadDebt;
    mapping(uint256 => Auction) public auctions;

    constructor(address collateral_, address quote_, uint256 duration_, uint256 floorBps_) {
        // TODO: revert with InvalidConfig for a zero duration or floorBps above 10000.
        owner = msg.sender;
        collateral = collateral_;
        quote = quote_;
        duration = duration_;
        floorBps = floorBps_;
    }

    function start(address user, uint256 lot, uint256 debt, uint256 startPrice) external returns (uint256 id) {
        // TODO: owner only; validate; pull the lot; store the auction; emit AuctionStarted.
        user; lot; debt; startPrice; id;
        revert("NOT_IMPLEMENTED");
    }

    function priceOf(uint256 id) public view returns (uint256) {
        // TODO: linear decay from startPrice to startPrice * floorBps / 10000 over duration.
        id;
        return 0;
    }

    function take(uint256 id, uint256 maxCollateral, uint256 maxPrice, address recipient)
        external
        returns (uint256 collateralOut, uint256 quoteIn)
    {
        // TODO: cap by lot, compute owe (round up), cap by debt (slice rounds down),
        //       move tokens, close with a refund or with bad debt.
        id; maxCollateral; maxPrice; recipient; collateralOut; quoteIn;
        revert("NOT_IMPLEMENTED");
    }

    function withdrawProceeds(address to) external returns (uint256 amount) {
        // TODO: owner only; send pendingProceeds to `to` and reset it.
        to; amount;
        revert("NOT_IMPLEMENTED");
    }
}
