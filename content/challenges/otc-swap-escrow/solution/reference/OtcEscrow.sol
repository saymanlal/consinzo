// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract OtcEscrow {
    error InvalidTokens();
    error ZeroAmount();
    error OrderNotActive();
    error NotMaker();
    error ExceedsRemaining();
    error TransferFailed();

    event OrderCreated(
        uint256 indexed orderId,
        address indexed maker,
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 buyAmount
    );
    event OrderFilled(uint256 indexed orderId, address indexed taker, uint256 takeAmount, uint256 cost);
    event OrderCancelled(uint256 indexed orderId, uint256 refunded);

    struct Order {
        address maker;
        address sellToken;
        address buyToken;
        uint256 sellAmount; // original amount offered
        uint256 buyAmount; // original amount asked for the whole offer
        uint256 remaining; // sell tokens still in escrow
        bool active;
    }

    uint256 public nextOrderId;
    mapping(uint256 => Order) public orders;

    function createOrder(address sellToken, address buyToken, uint256 sellAmount, uint256 buyAmount)
        external
        returns (uint256 orderId)
    {
        if (sellToken == address(0) || buyToken == address(0) || sellToken == buyToken) revert InvalidTokens();
        if (sellAmount == 0 || buyAmount == 0) revert ZeroAmount();

        orderId = nextOrderId++;
        orders[orderId] = Order({
            maker: msg.sender,
            sellToken: sellToken,
            buyToken: buyToken,
            sellAmount: sellAmount,
            buyAmount: buyAmount,
            remaining: sellAmount,
            active: true
        });

        if (!IERC20(sellToken).transferFrom(msg.sender, address(this), sellAmount)) revert TransferFailed();
        emit OrderCreated(orderId, msg.sender, sellToken, buyToken, sellAmount, buyAmount);
    }

    function quote(uint256 orderId, uint256 takeAmount) public view returns (uint256 cost) {
        Order storage o = orders[orderId];
        // Rounded up: the taker never pays less than the fixed price.
        return (takeAmount * o.buyAmount + o.sellAmount - 1) / o.sellAmount;
    }

    function fill(uint256 orderId, uint256 takeAmount) external returns (uint256 cost) {
        Order storage o = orders[orderId];
        if (!o.active) revert OrderNotActive();
        if (takeAmount == 0) revert ZeroAmount();
        if (takeAmount > o.remaining) revert ExceedsRemaining();

        cost = quote(orderId, takeAmount);
        o.remaining -= takeAmount;
        if (o.remaining == 0) o.active = false;

        if (!IERC20(o.buyToken).transferFrom(msg.sender, o.maker, cost)) revert TransferFailed();
        if (!IERC20(o.sellToken).transfer(msg.sender, takeAmount)) revert TransferFailed();
        emit OrderFilled(orderId, msg.sender, takeAmount, cost);
    }

    function cancel(uint256 orderId) external returns (uint256 refunded) {
        Order storage o = orders[orderId];
        if (!o.active) revert OrderNotActive();
        if (msg.sender != o.maker) revert NotMaker();

        refunded = o.remaining;
        o.remaining = 0;
        o.active = false;

        if (!IERC20(o.sellToken).transfer(msg.sender, refunded)) revert TransferFailed();
        emit OrderCancelled(orderId, refunded);
    }
}
