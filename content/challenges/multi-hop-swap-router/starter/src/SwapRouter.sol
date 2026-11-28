// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IPairFactory {
    /// @return pair The pair for the two tokens (in either order), or address(0) if none exists.
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);
    /// @notice Sends the requested outputs to `to`. The input must already be in the pair.
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
}

contract SwapRouter {
    error Expired();
    error InvalidPath();
    error PairNotFound();
    error ZeroAmount();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error TransferFailed();

    event Swapped(
        address indexed sender,
        address indexed to,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    IPairFactory public immutable factory;

    constructor(address factory_) {
        factory = IPairFactory(factory_);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        // TODO: Constant-product quote with a 0.3% fee on the input (README rule 1).
        revert("NOT_IMPLEMENTED");
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        // TODO: Validate the path, then chain getAmountOut over every hop using each pair's
        //       reserves in the right orientation.
        revert("NOT_IMPLEMENTED");
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        // TODO: Check the deadline, quote, check the minimum output, send the input to the first
        //       pair, then swap hop by hop with each output going to the next pair (or `to`).
        revert("NOT_IMPLEMENTED");
    }
}
