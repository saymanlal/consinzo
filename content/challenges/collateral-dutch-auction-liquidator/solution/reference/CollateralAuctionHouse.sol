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
        if (duration_ == 0 || floorBps_ > BPS) revert InvalidConfig();
        owner = msg.sender;
        collateral = collateral_;
        quote = quote_;
        duration = duration_;
        floorBps = floorBps_;
    }

    function start(address user, uint256 lot, uint256 debt, uint256 startPrice) external returns (uint256 id) {
        if (msg.sender != owner) revert NotOwner();
        if (lot == 0 || debt == 0 || startPrice == 0) revert ZeroAmount();
        id = auctionCount++;
        auctions[id] = Auction(user, lot, debt, startPrice, block.timestamp, true);
        IERC20Like(collateral).transferFrom(msg.sender, address(this), lot);
        emit AuctionStarted(id, user, lot, debt, startPrice);
    }

    function priceOf(uint256 id) public view returns (uint256) {
        Auction storage a = auctions[id];
        if (!a.active) revert AuctionNotActive();
        uint256 startPrice = a.startPrice;
        uint256 floor = (startPrice * floorBps) / BPS;
        uint256 elapsed = block.timestamp - a.startTime;
        if (elapsed >= duration) return floor;
        // The decay rounds down, so the price rounds up.
        return startPrice - ((startPrice - floor) * elapsed) / duration;
    }

    function take(uint256 id, uint256 maxCollateral, uint256 maxPrice, address recipient)
        external
        returns (uint256 collateralOut, uint256 quoteIn)
    {
        Auction storage a = auctions[id];
        if (!a.active) revert AuctionNotActive();
        if (maxCollateral == 0) revert ZeroAmount();
        uint256 price = priceOf(id);
        if (price > maxPrice) revert PriceTooHigh();

        uint256 lot = a.lot;
        uint256 debt = a.debt;
        collateralOut = maxCollateral < lot ? maxCollateral : lot;
        quoteIn = _mulDivUp(collateralOut, price, WAD);
        if (quoteIn > debt) {
            // Never raise more than the debt: shrink the slice to what the debt buys.
            quoteIn = debt;
            collateralOut = (quoteIn * WAD) / price;
        }

        lot -= collateralOut;
        debt -= quoteIn;
        pendingProceeds += quoteIn;

        uint256 refund;
        if (debt == 0) {
            refund = lot;
            lot = 0;
            a.active = false;
        } else if (lot == 0) {
            a.active = false;
            totalBadDebt += debt;
        }
        a.lot = lot;
        a.debt = debt;

        IERC20Like(quote).transferFrom(msg.sender, address(this), quoteIn);
        if (collateralOut > 0) IERC20Like(collateral).transfer(recipient, collateralOut);
        emit Take(id, msg.sender, collateralOut, quoteIn, price);

        if (!a.active) {
            if (refund > 0) IERC20Like(collateral).transfer(a.user, refund);
            emit AuctionClosed(id, refund, debt);
        }
    }

    function withdrawProceeds(address to) external returns (uint256 amount) {
        if (msg.sender != owner) revert NotOwner();
        amount = pendingProceeds;
        pendingProceeds = 0;
        IERC20Like(quote).transfer(to, amount);
    }

    function _mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        uint256 p = x * y;
        return p == 0 ? 0 : (p - 1) / d + 1;
    }
}
