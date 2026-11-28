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
        // TODO: Validate, store the order under the next id, escrow the sell tokens, emit OrderCreated.
        revert("NOT_IMPLEMENTED");
    }

    function quote(uint256 orderId, uint256 takeAmount) public view returns (uint256 cost) {
        // TODO: ceil(takeAmount * buyAmount / sellAmount) using the order's original amounts.
        revert("NOT_IMPLEMENTED");
    }

    function fill(uint256 orderId, uint256 takeAmount) external returns (uint256 cost) {
        // TODO: Checks in order: OrderNotActive, ZeroAmount, ExceedsRemaining. Update the order,
        //       pay the maker in buyToken, release sellToken to the taker, emit OrderFilled.
        revert("NOT_IMPLEMENTED");
    }

    function cancel(uint256 orderId) external returns (uint256 refunded) {
        // TODO: Checks in order: OrderNotActive, NotMaker. Close the order and return the remainder.
        revert("NOT_IMPLEMENTED");
    }
}
