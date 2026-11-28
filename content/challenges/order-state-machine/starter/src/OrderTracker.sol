// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract OrderTracker {
    enum Status {
        None,
        Created,
        Paid,
        Shipped,
        Delivered
    }

    error OrderNotFound(uint256 id);
    error NotBuyer(address caller);
    error NotSeller(address caller);
    error InvalidState(Status current);

    event OrderCreated(uint256 indexed id, address indexed buyer);
    event StatusChanged(uint256 indexed id, Status status);

    address public seller;
    uint256 public orderCount;

    constructor() {
        // TODO: the deployer is the seller
    }

    function createOrder() external returns (uint256 id) {
        // TODO: assign the next id (starting at 1), record the buyer, set status Created
        revert("NOT_IMPLEMENTED");
    }

    function pay(uint256 id) external {
        // TODO: buyer only, Created -> Paid
        revert("NOT_IMPLEMENTED");
    }

    function ship(uint256 id) external {
        // TODO: seller only, Paid -> Shipped
        revert("NOT_IMPLEMENTED");
    }

    function confirmDelivery(uint256 id) external {
        // TODO: buyer only, Shipped -> Delivered
        revert("NOT_IMPLEMENTED");
    }

    function statusOf(uint256 id) external view returns (Status) {
        // TODO: return the status (None for unknown ids)
        return Status.None;
    }

    function buyerOf(uint256 id) external view returns (address) {
        // TODO: return the buyer (address(0) for unknown ids)
        return address(0);
    }
}
