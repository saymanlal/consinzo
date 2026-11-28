// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract FeeConfig {
    error NotOwner();
    error ZeroAddress();
    error FeeTooHigh();

    uint256 public constant MAX_FEE_BPS = 1_000;

    address public owner;
    uint256 public feeBps;

    constructor() {
        _setOwner(msg.sender);
    }

    function setFee(uint256 newFeeBps) external {
        if (msg.sender != owner) revert NotOwner();
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = newFeeBps;
    }

    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) revert NotOwner();
        _setOwner(newOwner);
    }

    // TODO: VULNERABLE. This helper is part of the external interface.
    function _setOwner(address newOwner) public {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
}
