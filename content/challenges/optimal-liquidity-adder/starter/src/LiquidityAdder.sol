// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Subset of a Uniswap-V2-style pair used by the helper.
interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1);
    /// @dev Mints LP shares to `to` for the tokens received since the last reserve update.
    function mint(address to) external returns (uint256 liquidity);
}

contract LiquidityAdder {
    error Expired();
    error ZeroAddress();
    error InsufficientAmount();
    error InsufficientLiquidity();
    error Insufficient0Amount();
    error Insufficient1Amount();
    error TransferFailed();

    /// @notice Amount of asset B equal in value to `amountA` at the given reserves.
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        // TODO: InsufficientAmount() for a zero amount, then InsufficientLiquidity() for a zero reserve
        // TODO: amountA * reserveB / reserveA
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Largest deposit not exceeding the desired amounts that matches the reserve ratio.
    function optimalAmounts(
        address pair,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) public view returns (uint256 amount0, uint256 amount1) {
        // TODO: read the reserves; an empty pool accepts the desired amounts unchanged
        // TODO: otherwise find which token is the limiting side and enforce the minimum of the other
        revert("NOT_IMPLEMENTED");
    }

    function addLiquidity(
        address pair,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1, uint256 liquidity) {
        // TODO: deadline check, then recipient check
        // TODO: compute the optimal amounts
        // TODO: pull both tokens from msg.sender directly to the pair, checking the return values
        // TODO: mint LP shares to `to`
        revert("NOT_IMPLEMENTED");
    }
}
