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
        orderId = _submit(true, price, amount);
        if (!quote.transferFrom(msg.sender, address(this), amount * price)) revert TransferFailed();
    }

    function submitAsk(uint256 price, uint256 amount) external returns (uint256 orderId) {
        orderId = _submit(false, price, amount);
        if (!base.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function cancel(uint256 orderId) external {
        if (block.timestamp >= deadline) revert AuctionClosed();
        Order storage o = orders[orderId];
        if (o.owner != msg.sender) revert NotOrderOwner();
        if (o.claimed) revert AlreadyClaimed();
        uint256 amount = o.amount;
        o.amount = 0;
        o.claimed = true;
        if (o.isBid) _send(quote, msg.sender, amount * o.price);
        else _send(base, msg.sender, amount);
        emit OrderCancelled(orderId);
    }

    // ------------------------------------------------------------ clearing

    function clear() external {
        if (block.timestamp < deadline) revert AuctionStillOpen();
        if (cleared) revert AlreadyCleared();
        cleared = true;

        uint256 n = orders.length;
        Order[] memory book = new Order[](n);
        for (uint256 i = 0; i < n; i++) book[i] = orders[i];

        uint256 bestPrice;
        uint256 bestVolume;
        uint256 bestImbalance;
        for (uint256 i = 0; i < n; i++) {
            if (book[i].amount == 0) continue;
            uint256 p = book[i].price;
            (uint256 demand, uint256 supply) = _depthAt(book, p);
            uint256 volume = demand < supply ? demand : supply;
            uint256 imbalance = demand < supply ? supply - demand : demand - supply;
            if (
                volume > bestVolume ||
                (volume == bestVolume &&
                    volume != 0 &&
                    (imbalance < bestImbalance || (imbalance == bestImbalance && p < bestPrice)))
            ) {
                bestPrice = p;
                bestVolume = volume;
                bestImbalance = imbalance;
            }
        }

        if (bestVolume != 0) {
            clearingPrice = bestPrice;
            clearedVolume = bestVolume;
            _allocate(book, true, bestPrice, bestVolume);
            _allocate(book, false, bestPrice, bestVolume);
        }
        emit Cleared(clearingPrice, clearedVolume);
    }

    // ------------------------------------------------------------ settlement

    function claim(uint256 orderId) external returns (uint256 baseOut, uint256 quoteOut) {
        if (!cleared) revert NotCleared();
        Order storage o = orders[orderId];
        if (o.claimed) revert AlreadyClaimed();
        o.claimed = true;
        if (o.isBid) {
            baseOut = o.filled;
            // Escrow was taken at the limit price; the difference to the clearing price is refunded.
            quoteOut = o.amount * o.price - o.filled * clearingPrice;
        } else {
            baseOut = o.amount - o.filled;
            quoteOut = o.filled * clearingPrice;
        }
        if (baseOut != 0) _send(base, o.owner, baseOut);
        if (quoteOut != 0) _send(quote, o.owner, quoteOut);
        emit Claimed(orderId, baseOut, quoteOut);
    }

    function _submit(bool isBid, uint256 price, uint256 amount) internal returns (uint256 orderId) {
        if (block.timestamp >= deadline) revert AuctionClosed();
        if (price == 0 || amount == 0) revert InvalidOrder();
        orderId = orders.length;
        if (orderId >= MAX_ORDERS) revert TooManyOrders();
        orders.push(Order(msg.sender, isBid, price, amount, 0, false));
        emit OrderSubmitted(orderId, msg.sender, isBid, price, amount);
    }
    function _depthAt(Order[] memory book, uint256 p) internal pure returns (uint256 demand, uint256 supply) {
        for (uint256 i = 0; i < book.length; i++) {
            if (book[i].isBid) {
                if (book[i].price >= p) demand += book[i].amount;
            } else {
                if (book[i].price <= p) supply += book[i].amount;
            }
        }
    }
    /// @dev Distributes `volume` over one side by price priority, then by id. `filled` in the
    ///      memory copy marks orders that were already served in this pass.
    function _allocate(Order[] memory book, bool isBid, uint256 price, uint256 volume) internal {
        while (volume != 0) {
            uint256 pick = type(uint256).max;
            for (uint256 i = 0; i < book.length; i++) {
                Order memory o = book[i];
                if (o.isBid != isBid || o.amount == 0 || o.filled != 0) continue;
                if (isBid ? o.price < price : o.price > price) continue;
                if (
                    pick == type(uint256).max ||
                    (isBid ? o.price > book[pick].price : o.price < book[pick].price)
                ) {
                    pick = i;
                }
            }
            uint256 fill = book[pick].amount < volume ? book[pick].amount : volume;
            book[pick].filled = fill;
            orders[pick].filled = fill;
            volume -= fill;
        }
    }
    function _send(IToken token, address to, uint256 amount) internal {
        if (!token.transfer(to, amount)) revert TransferFailed();
    }
}
