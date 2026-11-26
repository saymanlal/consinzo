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
        token0 = IMintableERC20(_token0);
        token1 = IMintableERC20(_token1);
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 mintedShares) {
        revert("NOT_IMPLEMENTED");
    }

    function removeLiquidity(uint256 shareAmount) external returns (uint256 amount0, uint256 amount1) {
        revert("NOT_IMPLEMENTED");
    }

    function swap(address tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
        revert("NOT_IMPLEMENTED");
    }
}
