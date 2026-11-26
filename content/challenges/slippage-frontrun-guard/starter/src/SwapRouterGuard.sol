// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPool {
    function swap(uint256 amountIn) external returns (uint256 amountOut);
}

contract SwapRouterGuard {
    IPool public immutable pool;
    constructor(address _pool) { pool = IPool(_pool); }

    function swapExactIn(uint256 amountIn, uint256 minAmountOut, uint256 deadline) external returns (uint256 amountOut) {
        // VULNERABLE: Ignores deadline and minAmountOut!
        amountOut = pool.swap(amountIn);
    }
}