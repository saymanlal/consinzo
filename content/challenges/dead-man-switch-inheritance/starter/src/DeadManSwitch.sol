// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title Wallet that passes to an heir after the owner has been silent for a full period.
contract DeadManSwitch {
    address public owner;
    address public heir;
    uint256 public immutable silencePeriod;
    uint256 public lastHeartbeat;

    event Heartbeat(uint256 timestamp);
    event HeirChanged(address indexed newHeir);
    event Inherited(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NotHeir();
    error InvalidHeir();
    error InvalidPeriod();
    error OwnerStillActive();
    error TransferFailed();

    constructor(address _heir, uint256 _silencePeriod) payable {
        if (_heir == address(0) || _heir == msg.sender) revert InvalidHeir();
        if (_silencePeriod == 0) revert InvalidPeriod();
        owner = msg.sender;
        heir = _heir;
        silencePeriod = _silencePeriod;
        lastHeartbeat = block.timestamp;
    }

    receive() external payable {}

    function heartbeat() external {
        // TODO: Only the owner. Record block.timestamp as the last heartbeat and emit Heartbeat.
        revert("NOT_IMPLEMENTED");
    }

    function setHeir(address newHeir) external {
        // TODO: Only the owner. Reject address(0) and the owner itself.
        // TODO: Store the heir, count the call as a heartbeat and emit HeirChanged.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 amount) external {
        // TODO: Only the owner. Count the call as a heartbeat, then send `amount` wei to the owner.
        revert("NOT_IMPLEMENTED");
    }

    function claimableAt() public view returns (uint256) {
        // TODO: Return the first timestamp at which the heir may claim.
        revert("NOT_IMPLEMENTED");
    }

    function claim() external {
        // TODO: Only the heir, and only once the owner has been silent for the whole period.
        // TODO: Hand ownership to the heir, clear the heir slot, restart the timer and emit Inherited.
        revert("NOT_IMPLEMENTED");
    }
}
