// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract FeeConfig {
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000;
    uint256 public constant LOCK_PERIOD = 7 days;

    address public immutable treasury;
    uint256 public immutable feeBps;
    uint256 public immutable deployedAt;

    error ZeroTreasury();
    error FeeTooHigh(uint256 feeBps, uint256 maxFeeBps);

    constructor(address treasury_, uint256 feeBps_) {
        // TODO: revert with ZeroTreasury() when treasury_ is the zero address
        // TODO: revert with FeeTooHigh(feeBps_, MAX_FEE_BPS) when feeBps_ exceeds MAX_FEE_BPS
        // TODO: assign treasury, feeBps and deployedAt
    }

    function feeFor(uint256 amount) external view returns (uint256) {
        // TODO: amount * feeBps / BPS_DENOMINATOR, rounded down
        revert("NOT_IMPLEMENTED");
    }

    function netAmount(uint256 amount) external view returns (uint256) {
        // TODO: amount minus the fee
        revert("NOT_IMPLEMENTED");
    }

    function unlockTime() external view returns (uint256) {
        // TODO: deployedAt + LOCK_PERIOD
        revert("NOT_IMPLEMENTED");
    }

    function isUnlocked() external view returns (bool) {
        // TODO: true once block.timestamp has reached unlockTime()
        revert("NOT_IMPLEMENTED");
    }
}
