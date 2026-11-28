// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BpsMath {
    uint256 public constant BPS_DENOMINATOR = 10_000;

    error InvalidBps(uint256 bps);

    function mulBpsDown(uint256 amount, uint256 bps) external pure returns (uint256) {
        return _mulBps(amount, bps, false);
    }

    function mulBpsUp(uint256 amount, uint256 bps) external pure returns (uint256) {
        return _mulBps(amount, bps, true);
    }

    function splitFee(uint256 amount, uint256 feeBps) external pure returns (uint256 fee, uint256 net) {
        // Rounding the fee up favours the party collecting it. Deriving `net` by
        // subtraction guarantees that the two parts add up to `amount` exactly.
        fee = _mulBps(amount, feeBps, true);
        net = amount - fee;
    }

    /// @dev Exact amount * bps / 10_000 for every uint256 amount.
    ///
    /// Write amount = q * D + r with D = 10_000 and 0 <= r < D. Then
    ///   amount * bps / D = q * bps + (r * bps) / D.
    /// q * bps is an integer, so all rounding happens in the second term, and
    /// r * bps < D * D = 1e8 cannot overflow. Because bps <= D, the result is at most
    /// amount, so the final sum cannot overflow either.
    function _mulBps(uint256 amount, uint256 bps, bool roundUp) internal pure returns (uint256) {
        if (bps > BPS_DENOMINATOR) revert InvalidBps(bps);

        uint256 whole = (amount / BPS_DENOMINATOR) * bps;
        uint256 partNumerator = (amount % BPS_DENOMINATOR) * bps;

        uint256 part = partNumerator / BPS_DENOMINATOR;
        if (roundUp && partNumerator % BPS_DENOMINATOR != 0) {
            part += 1;
        }
        return whole + part;
    }
}
