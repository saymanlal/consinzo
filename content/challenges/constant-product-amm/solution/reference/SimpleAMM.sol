// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IMintableERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract SimpleAMM {
    IMintableERC20 public immutable token0;
    IMintableERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalShares;
    mapping(address => uint256) public shares;

    constructor(address _token0, address _token1) {
        require(_token0 != address(0) && _token1 != address(0) && _token0 != _token1, "INVALID_TOKENS");
        token0 = IMintableERC20(_token0);
        token1 = IMintableERC20(_token1);
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 mintedShares) {
        require(amount0 > 0 && amount1 > 0, "ZERO_AMOUNTS");
        require(token0.transferFrom(msg.sender, address(this), amount0), "T0_PULL_FAILED");
        require(token1.transferFrom(msg.sender, address(this), amount1), "T1_PULL_FAILED");

        if (totalShares == 0) {
            mintedShares = _sqrt(amount0 * amount1);
        } else {
            uint256 s0 = (amount0 * totalShares) / reserve0;
            uint256 s1 = (amount1 * totalShares) / reserve1;
            mintedShares = s0 < s1 ? s0 : s1;
        }
        require(mintedShares > 0, "ZERO_SHARES");
        shares[msg.sender] += mintedShares;
        totalShares += mintedShares;
        reserve0 += amount0;
        reserve1 += amount1;
    }

    function removeLiquidity(uint256 shareAmount) external returns (uint256 amount0, uint256 amount1) {
        require(shareAmount > 0 && shares[msg.sender] >= shareAmount, "INVALID_SHARES");
        amount0 = (shareAmount * reserve0) / totalShares;
        amount1 = (shareAmount * reserve1) / totalShares;
        require(amount0 > 0 && amount1 > 0, "ZERO_OUTPUT");

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        reserve0 -= amount0;
        reserve1 -= amount1;

        require(token0.transfer(msg.sender, amount0), "T0_SEND_FAILED");
        require(token1.transfer(msg.sender, amount1), "T1_SEND_FAILED");
    }

    function swap(address tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
        require(amountIn > 0, "ZERO_IN");
        bool isToken0 = tokenIn == address(token0);
        require(isToken0 || tokenIn == address(token1), "INVALID_TOKEN_IN");

        (IMintableERC20 inToken, IMintableERC20 outToken, uint256 resIn, uint256 resOut) = isToken0
            ? (token0, token1, reserve0, reserve1)
            : (token1, token0, reserve1, reserve0);

        require(inToken.transferFrom(msg.sender, address(this), amountIn), "PULL_FAILED");

        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * resOut) / (resIn * 1000 + amountInWithFee);
        require(amountOut > 0 && amountOut < resOut, "INSUFFICIENT_OUT");

        if (isToken0) {
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        require(outToken.transfer(msg.sender, amountOut), "SEND_FAILED");
    }
}
