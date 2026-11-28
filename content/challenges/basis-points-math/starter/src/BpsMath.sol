// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BpsMath {
    uint256 public constant BPS_DENOMINATOR = 10_000;

    error InvalidBps(uint256 bps);

    function mulBpsDown(uint256 amount, uint256 bps) external pure returns (uint256) {
        // TODO: validate bps, return floor(amount * bps / 10_000) without overflowing
        return 0;
    }

    function mulBpsUp(uint256 amount, uint256 bps) external pure returns (uint256) {
        // TODO: validate bps, return ceil(amount * bps / 10_000) without overflowing
        return 0;
    }

    function splitFee(uint256 amount, uint256 feeBps) external pure returns (uint256 fee, uint256 net) {
        // TODO: fee is rounded up; net is the rest, so fee + net == amount
        return (0, 0);
    }
}
