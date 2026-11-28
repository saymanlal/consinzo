// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract FeeConfig {
    // Constants are inlined into the bytecode at compile time and cost no storage.
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000;
    uint256 public constant LOCK_PERIOD = 7 days;

    // Immutables are written into the deployed bytecode once, during construction.
    address public immutable treasury;
    uint256 public immutable feeBps;
    uint256 public immutable deployedAt;

    error ZeroTreasury();
    error FeeTooHigh(uint256 feeBps, uint256 maxFeeBps);

    constructor(address treasury_, uint256 feeBps_) {
        if (treasury_ == address(0)) revert ZeroTreasury();
        if (feeBps_ > MAX_FEE_BPS) revert FeeTooHigh(feeBps_, MAX_FEE_BPS);

        treasury = treasury_;
        feeBps = feeBps_;
        deployedAt = block.timestamp;
    }

    function feeFor(uint256 amount) external view returns (uint256) {
        return _feeFor(amount);
    }

    function netAmount(uint256 amount) external view returns (uint256) {
        // Derived from the fee so that fee + net == amount for every input.
        return amount - _feeFor(amount);
    }

    function unlockTime() external view returns (uint256) {
        return deployedAt + LOCK_PERIOD;
    }

    function isUnlocked() external view returns (bool) {
        return block.timestamp >= deployedAt + LOCK_PERIOD;
    }

    function _feeFor(uint256 amount) private view returns (uint256) {
        // Multiply first: dividing first would round small amounts down to zero.
        return (amount * feeBps) / BPS_DENOMINATOR;
    }
}
