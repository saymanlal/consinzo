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
        if (msg.sender != owner) revert NotOwner();
        lastHeartbeat = block.timestamp;
        emit Heartbeat(block.timestamp);
    }

    function setHeir(address newHeir) external {
        if (msg.sender != owner) revert NotOwner();
        if (newHeir == address(0) || newHeir == msg.sender) revert InvalidHeir();
        heir = newHeir;
        lastHeartbeat = block.timestamp;
        emit HeirChanged(newHeir);
    }

    function withdraw(uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        lastHeartbeat = block.timestamp;
        // A balance shortfall makes the call fail, which surfaces as TransferFailed.
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function claimableAt() public view returns (uint256) {
        return lastHeartbeat + silencePeriod;
    }

    function claim() external {
        if (msg.sender != heir) revert NotHeir();
        if (block.timestamp < claimableAt()) revert OwnerStillActive();

        address previousOwner = owner;
        owner = msg.sender;
        // The new owner starts with no heir and a fresh timer, so nobody can claim again
        // until the new owner names an heir and then goes silent.
        heir = address(0);
        lastHeartbeat = block.timestamp;
        emit Inherited(previousOwner, msg.sender);
    }
}
