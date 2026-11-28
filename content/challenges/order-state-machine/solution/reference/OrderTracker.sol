// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract OrderTracker {
    // None is first so that it is the default value of unset storage:
    // an id that was never created reads as None.
    enum Status {
        None,
        Created,
        Paid,
        Shipped,
        Delivered
    }

    struct Order {
        address buyer;
        Status status;
    }

    error OrderNotFound(uint256 id);
    error NotBuyer(address caller);
    error NotSeller(address caller);
    error InvalidState(Status current);

    event OrderCreated(uint256 indexed id, address indexed buyer);
    event StatusChanged(uint256 indexed id, Status status);

    address public immutable seller;
    uint256 public orderCount;

    mapping(uint256 => Order) private _orders;

    constructor() {
        seller = msg.sender;
    }

    function createOrder() external returns (uint256 id) {
        id = ++orderCount;
        _orders[id] = Order({buyer: msg.sender, status: Status.Created});
        emit OrderCreated(id, msg.sender);
    }

    function pay(uint256 id) external {
        _advance(id, false, Status.Created, Status.Paid);
    }

    function ship(uint256 id) external {
        _advance(id, true, Status.Paid, Status.Shipped);
    }

    function confirmDelivery(uint256 id) external {
        _advance(id, false, Status.Shipped, Status.Delivered);
    }

    function statusOf(uint256 id) external view returns (Status) {
        return _orders[id].status;
    }

    function buyerOf(uint256 id) external view returns (address) {
        return _orders[id].buyer;
    }

    /// @dev Single place where a transition is validated: existence, then caller, then state.
    function _advance(uint256 id, bool sellerOnly, Status expected, Status next) internal {
        Order storage order = _orders[id];
        Status current = order.status;

        if (current == Status.None) revert OrderNotFound(id);
        if (sellerOnly) {
            if (msg.sender != seller) revert NotSeller(msg.sender);
        } else {
            if (msg.sender != order.buyer) revert NotBuyer(msg.sender);
        }
        if (current != expected) revert InvalidState(current);

        order.status = next;
        emit StatusChanged(id, next);
    }
}
