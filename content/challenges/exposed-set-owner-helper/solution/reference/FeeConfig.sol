// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract FeeConfig {
    error NotOwner();
    error ZeroAddress();
    error FeeTooHigh();

    uint256 public constant MAX_FEE_BPS = 1_000;

    address public owner;
    uint256 public feeBps;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        _setOwner(msg.sender);
    }

    function setFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = newFeeBps;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        _setOwner(newOwner);
    }

    /// @dev `internal` removes the function from the ABI. It has no selector, so the only
    ///      way to reach it is through code inside this contract that has already
    ///      checked the caller.
    function _setOwner(address newOwner) internal {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
}
