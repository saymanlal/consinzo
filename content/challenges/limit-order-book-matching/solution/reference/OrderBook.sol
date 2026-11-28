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
        if (price == 0 || amount == 0) revert InvalidOrder();
        uint256 remaining = amount;
        while (remaining != 0) {
            uint256 fill = _matchHead(isBuy, price, remaining);
            if (fill == 0) break;
            remaining -= fill;
        }
        filled = amount - remaining;

        if (remaining != 0) {
            orderId = _insert(isBuy, price, remaining);
            // Resting bids escrow quote at their own price, resting asks escrow base.
            if (isBuy) _pull(quote, msg.sender, address(this), remaining * price);
            else _pull(base, msg.sender, address(this), remaining);
            emit OrderPlaced(orderId, msg.sender, isBuy, price, remaining);
        }
    }

    function cancelOrder(uint256 orderId) external {
        Order memory o = orders[orderId];
        if (o.owner != msg.sender) revert NotOrderOwner();
        _remove(orderId);
        if (o.isBuy) _push(quote, msg.sender, o.remaining * o.price);
        else _push(base, msg.sender, o.remaining);
        emit OrderCancelled(orderId, o.remaining);
    }

    /// @dev Tries to fill the taker against the best opposite order. Returns the base filled,
    ///      or 0 when the book is empty or the best price does not cross the limit.
    function _matchHead(bool takerIsBuy, uint256 limitPrice, uint256 want) internal returns (uint256 fill) {
        uint256 makerId = takerIsBuy ? bestAsk : bestBid;
        if (makerId == 0) return 0;
        Order storage maker = orders[makerId];
        uint256 tradePrice = maker.price;
        if (takerIsBuy ? tradePrice > limitPrice : tradePrice < limitPrice) return 0;

        address makerOwner = maker.owner;
        fill = want < maker.remaining ? want : maker.remaining;
        if (fill == maker.remaining) _remove(makerId);
        else maker.remaining -= fill;
        emit Trade(makerId, msg.sender, tradePrice, fill);

        if (takerIsBuy) {
            // Taker pays the seller directly; the book releases the seller's escrowed base.
            _pull(quote, msg.sender, makerOwner, fill * tradePrice);
            _push(base, msg.sender, fill);
        } else {
            // Taker delivers base to the buyer; the book releases the buyer's escrowed quote.
            _pull(base, msg.sender, makerOwner, fill);
            _push(quote, msg.sender, fill * tradePrice);
        }
    }
    function _insert(bool isBuy, uint256 price, uint256 amount) internal returns (uint256 id) {
        uint256 prev = 0;
        uint256 cur = isBuy ? bestBid : bestAsk;
        // Skip every order that is at least as good: equal prices keep earlier orders in front.
        while (cur != 0 && (isBuy ? orders[cur].price >= price : orders[cur].price <= price)) {
            prev = cur;
            cur = orders[cur].next;
        }
        id = nextOrderId++;
        orders[id] = Order(msg.sender, isBuy, price, amount, prev, cur);
        if (prev == 0) {
            if (isBuy) bestBid = id;
            else bestAsk = id;
        } else {
            orders[prev].next = id;
        }
        if (cur != 0) orders[cur].prev = id;
    }
    function _remove(uint256 id) internal {
        Order storage o = orders[id];
        uint256 prev = o.prev;
        uint256 next = o.next;
        if (prev == 0) {
            if (o.isBuy) bestBid = next;
            else bestAsk = next;
        } else {
            orders[prev].next = next;
        }
        if (next != 0) orders[next].prev = prev;
        delete orders[id];
    }
    function _pull(IToken token, address from, address to, uint256 amount) internal {
        if (!token.transferFrom(from, to, amount)) revert TransferFailed();
    }
    function _push(IToken token, address to, uint256 amount) internal {
        if (!token.transfer(to, amount)) revert TransferFailed();
    }
}
