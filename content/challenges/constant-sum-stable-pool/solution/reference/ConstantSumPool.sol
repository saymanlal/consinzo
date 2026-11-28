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
        if (token0_ == token1_) revert IdenticalTokens();
        if (feeBps_ > MAX_FEE_BPS) revert FeeTooHigh();
        token0 = token0_;
        token1 = token1_;
        feeBps = feeBps_;
    }

    function _ceilDiv(uint256 a, uint256 b) private pure returns (uint256) {
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    function _pull(address token, uint256 amount) private {
        if (amount == 0) return;
        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function _push(address token, uint256 amount) private {
        if (amount == 0) return;
        if (!IERC20(token).transfer(msg.sender, amount)) revert TransferFailed();
    }

    function getAmountOut(uint256 amountIn) public view returns (uint256) {
        return amountIn - _ceilDiv(amountIn * feeBps, BPS);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        bool zeroForOne = tokenIn == token0;
        if (!zeroForOne && tokenIn != token1) revert InvalidToken();
        if (amountIn == 0) revert ZeroAmount();
        amountOut = getAmountOut(amountIn);
        if (amountOut < minAmountOut) revert SlippageExceeded();

        if (zeroForOne) {
            if (amountOut > reserve1) revert InsufficientLiquidity();
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            if (amountOut > reserve0) revert InsufficientLiquidity();
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        _pull(tokenIn, amountIn);
        _push(zeroForOne ? token1 : token0, amountOut);
        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    function addLiquidity(uint256 amount0Max, uint256 amount1Max)
        external
        returns (uint256 shares, uint256 amount0, uint256 amount1)
    {
        uint256 supply = totalSupply;
        if (supply == 0) {
            shares = amount0Max + amount1Max;
            amount0 = amount0Max;
            amount1 = amount1Max;
        } else {
            uint256 r0 = reserve0;
            uint256 r1 = reserve1;
            // A constant-sum pool can hold zero of one token; that side is then skipped.
            shares = type(uint256).max;
            if (r0 > 0) shares = (amount0Max * supply) / r0;
            if (r1 > 0) {
                uint256 s1 = (amount1Max * supply) / r1;
                if (s1 < shares) shares = s1;
            }
            // Pull the exact proportional amounts, rounded up in the pool's favour. Because
            // shares was rounded down from amountMax, the result never exceeds the maximum.
            amount0 = _ceilDiv(shares * r0, supply);
            amount1 = _ceilDiv(shares * r1, supply);
        }
        if (shares == 0) revert ZeroShares();

        totalSupply = supply + shares;
        balanceOf[msg.sender] += shares;
        reserve0 += amount0;
        reserve1 += amount1;

        _pull(token0, amount0);
        _pull(token1, amount1);
        emit LiquidityAdded(msg.sender, shares, amount0, amount1);
    }

    function removeLiquidity(uint256 shares, uint256 min0, uint256 min1)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (shares == 0) revert ZeroAmount();
        if (shares > balanceOf[msg.sender]) revert InsufficientShares();

        uint256 supply = totalSupply;
        amount0 = (shares * reserve0) / supply;
        amount1 = (shares * reserve1) / supply;
        if (amount0 < min0 || amount1 < min1) revert SlippageExceeded();

        balanceOf[msg.sender] -= shares;
        totalSupply = supply - shares;
        reserve0 -= amount0;
        reserve1 -= amount1;

        _push(token0, amount0);
        _push(token1, amount1);
        emit LiquidityRemoved(msg.sender, shares, amount0, amount1);
    }
}
