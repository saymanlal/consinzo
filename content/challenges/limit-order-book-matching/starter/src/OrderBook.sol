// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Limit order book for one base/quote pair with price-time priority.
/// @dev Prices are quote units per one base unit, so `quote = base * price` is exact.
contract OrderBook {
    struct Order {
        address owner;
        bool isBuy;
        uint256 price;
        uint256 remaining; // base units still open
        uint256 prev; // better (or earlier) order on the same side, 0 at the head
        uint256 next; // worse (or later) order on the same side, 0 at the tail
    }

    error InvalidOrder();
    error NotOrderOwner();
    error TransferFailed();

    event OrderPlaced(uint256 indexed orderId, address indexed owner, bool isBuy, uint256 price, uint256 amount);
    event Trade(uint256 indexed makerOrderId, address indexed taker, uint256 price, uint256 amount);
    event OrderCancelled(uint256 indexed orderId, uint256 remaining);

    IToken public immutable base;
    IToken public immutable quote;

    uint256 public nextOrderId = 1;
    uint256 public bestBid; // head of the buy list (highest price), 0 if empty
    uint256 public bestAsk; // head of the sell list (lowest price), 0 if empty
    mapping(uint256 => Order) public orders;

    constructor(IToken base_, IToken quote_) {
        base = base_;
        quote = quote_;
    }

    function placeLimitOrder(bool isBuy, uint256 price, uint256 amount)
        external
        returns (uint256 orderId, uint256 filled)
    {
        // TODO: InvalidOrder for a zero price or amount.
        //       Match against the head of the opposite list while it crosses the limit price:
        //       fill min(remaining, maker.remaining) at the MAKER's price, settle both legs,
        //       remove a fully filled maker, emit Trade.
        //       If something is left, escrow it, insert it into the caller's side in
        //       price-time order and emit OrderPlaced. orderId is 0 when nothing rests.
        revert("NOT_IMPLEMENTED");
    }

    function cancelOrder(uint256 orderId) external {
        // TODO: only the order's owner (NotOrderOwner, also for unknown or finished orders);
        //       unlink the order, delete it, refund the remaining escrow, emit OrderCancelled.
        revert("NOT_IMPLEMENTED");
    }
}
