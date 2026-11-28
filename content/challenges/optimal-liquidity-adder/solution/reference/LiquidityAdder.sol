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
        if (amountA == 0) revert InsufficientAmount();
        if (reserveA == 0 || reserveB == 0) revert InsufficientLiquidity();
        amountB = (amountA * reserveB) / reserveA;
    }

    /// @notice Largest deposit not exceeding the desired amounts that matches the reserve ratio.
    function optimalAmounts(
        address pair,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) public view returns (uint256 amount0, uint256 amount1) {
        (uint256 reserve0, uint256 reserve1) = IPair(pair).getReserves();

        // Empty pool: there is no ratio to respect, the first depositor sets the price.
        if (reserve0 == 0 && reserve1 == 0) {
            return (amount0Desired, amount1Desired);
        }

        // Try to use all of token0. If that needs more token1 than offered, token1 is the
        // limiting side and token0 is scaled down instead.
        uint256 amount1Optimal = quote(amount0Desired, reserve0, reserve1);
        if (amount1Optimal <= amount1Desired) {
            if (amount1Optimal < amount1Min) revert Insufficient1Amount();
            return (amount0Desired, amount1Optimal);
        }

        // amount1Optimal > amount1Desired implies amount0Optimal <= amount0Desired, because
        // both divisions round down.
        uint256 amount0Optimal = quote(amount1Desired, reserve1, reserve0);
        if (amount0Optimal < amount0Min) revert Insufficient0Amount();
        return (amount0Optimal, amount1Desired);
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
        if (block.timestamp > deadline) revert Expired();
        if (to == address(0)) revert ZeroAddress();

        (amount0, amount1) = optimalAmounts(pair, amount0Desired, amount1Desired, amount0Min, amount1Min);

        // Tokens go straight from the caller to the pair; the helper never has custody,
        // so there is nothing to sweep and nothing to strand here.
        if (!IERC20Minimal(IPair(pair).token0()).transferFrom(msg.sender, pair, amount0)) revert TransferFailed();
        if (!IERC20Minimal(IPair(pair).token1()).transferFrom(msg.sender, pair, amount1)) revert TransferFailed();

        liquidity = IPair(pair).mint(to);
    }
}
