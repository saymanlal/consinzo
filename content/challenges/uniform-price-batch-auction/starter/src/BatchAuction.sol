// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Single-round batch auction with a uniform clearing price.
/// @dev Prices are quote units per one base unit, so `quote = base * price` is exact.
contract BatchAuction {
    struct Order {
        address owner;
        bool isBid;
        uint256 price; // limit price
        uint256 amount; // base units; set to 0 when cancelled
        uint256 filled; // base units matched at the clearing price
        bool claimed;
    }

    error InvalidOrder();
    error AuctionClosed();
    error AuctionStillOpen();
    error AlreadyCleared();
    error NotCleared();
    error NotOrderOwner();
    error AlreadyClaimed();
    error TooManyOrders();
    error TransferFailed();

    event OrderSubmitted(uint256 indexed orderId, address indexed owner, bool isBid, uint256 price, uint256 amount);
    event OrderCancelled(uint256 indexed orderId);
    event Cleared(uint256 clearingPrice, uint256 volume);
    event Claimed(uint256 indexed orderId, uint256 baseOut, uint256 quoteOut);

    uint256 public constant MAX_ORDERS = 40;

    IToken public immutable base;
    IToken public immutable quote;
    uint256 public immutable deadline; // orders are accepted while block.timestamp < deadline

    bool public cleared;
    uint256 public clearingPrice;
    uint256 public clearedVolume;
    Order[] public orders;

    constructor(IToken base_, IToken quote_, uint256 deadline_) {
        base = base_;
        quote = quote_;
        deadline = deadline_;
    }

    function orderCount() external view returns (uint256) {
        return orders.length;
    }

    // ------------------------------------------------------------ order phase

    function submitBid(uint256 price, uint256 amount) external returns (uint256 orderId) {
        // TODO: store a bid and escrow amount * price quote from the caller.
        revert("NOT_IMPLEMENTED");
    }

    function submitAsk(uint256 price, uint256 amount) external returns (uint256 orderId) {
        // TODO: store an ask and escrow amount base from the caller.
        revert("NOT_IMPLEMENTED");
    }

    function cancel(uint256 orderId) external {
        // TODO: before the deadline only (AuctionClosed); owner only (NotOrderOwner);
        //       AlreadyClaimed if it was cancelled before; refund the full escrow, set amount
        //       to 0 and claimed to true; emit OrderCancelled.
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ clearing

    function clear() external {
        // TODO: after the deadline (AuctionStillOpen), once (AlreadyCleared).
        //       1. For every order price p: demand = sum of bid amounts with price >= p,
        //          supply = sum of ask amounts with price <= p, volume = min(demand, supply).
        //       2. Pick the price with the largest volume; ties: smallest |demand - supply|,
        //          then lowest price. If the best volume is 0 the clearing price is 0.
        //       3. Give the volume to bids (highest price first, then lowest id) and to asks
        //          (lowest price first, then lowest id) and store each order's `filled`.
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ settlement

    function claim(uint256 orderId) external returns (uint256 baseOut, uint256 quoteOut) {
        // TODO: NotCleared before clearing; AlreadyClaimed for claimed or cancelled orders.
        //       Anyone may call; funds go to the order's owner.
        //       Bid: filled base, plus amount * price - filled * clearingPrice quote.
        //       Ask: filled * clearingPrice quote, plus amount - filled base.
        revert("NOT_IMPLEMENTED");
    }
}
