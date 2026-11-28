// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ConstantSumPool {
    error IdenticalTokens();
    error FeeTooHigh();
    error InvalidToken();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error TransferFailed();

    event Swap(address indexed sender, address indexed tokenIn, uint256 amountIn, uint256 amountOut);
    event LiquidityAdded(address indexed provider, uint256 shares, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(address indexed provider, uint256 shares, uint256 amount0, uint256 amount1);

    uint256 internal constant BPS = 10_000;
    uint256 public constant MAX_FEE_BPS = 100;

    address public immutable token0;
    address public immutable token1;
    uint256 public immutable feeBps;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address token0_, address token1_, uint256 feeBps_) {
        // TODO: Revert with IdenticalTokens / FeeTooHigh for invalid parameters.
        token0 = token0_;
        token1 = token1_;
        feeBps = feeBps_;
    }

    function getAmountOut(uint256 amountIn) public view returns (uint256) {
        // TODO: amountIn minus the fee, where the fee is rounded up.
        revert("NOT_IMPLEMENTED");
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        // TODO: Checks in order: InvalidToken, ZeroAmount, SlippageExceeded, InsufficientLiquidity.
        //       Update both reserves, pull the input, send the output, emit Swap.
        revert("NOT_IMPLEMENTED");
    }

    function addLiquidity(uint256 amount0Max, uint256 amount1Max)
        external
        returns (uint256 shares, uint256 amount0, uint256 amount1)
    {
        // TODO: First deposit: shares = amount0Max + amount1Max, both pulled in full.
        //       Later deposits: shares limited by the scarcer side, amounts pulled rounded up
        //       (README rule 5). Revert ZeroShares, mint, update reserves, emit LiquidityAdded.
        revert("NOT_IMPLEMENTED");
    }

    function removeLiquidity(uint256 shares, uint256 min0, uint256 min1)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        // TODO: Validate, compute the pro-rata amounts rounded down, check the minima, burn,
        //       update reserves, pay out, emit LiquidityRemoved.
        revert("NOT_IMPLEMENTED");
    }
}
