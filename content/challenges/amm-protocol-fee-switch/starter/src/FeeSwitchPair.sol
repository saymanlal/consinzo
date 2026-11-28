// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Minimal token interface used by the pair. Provided; do not edit.
interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Constant-product pair with a protocol fee switch (kLast accounting).
contract FeeSwitchPair {
    error NotOwner();
    error InvalidToken();
    error ZeroAmount();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidity();
    error InsufficientOutput();

    event Mint(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);
    event Swap(address indexed sender, address indexed tokenIn, uint256 amountIn, uint256 amountOut, address indexed to);
    event ProtocolFeeMinted(address indexed feeTo, uint256 liquidity);

    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    address public immutable owner;
    address public immutable token0;
    address public immutable token1;
    address public feeTo;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public kLast;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address token0_, address token1_) {
        owner = msg.sender;
        token0 = token0_;
        token1 = token1_;
    }

    function setFeeTo(address newFeeTo) external {
        // TODO: owner only; store the recipient (address(0) turns the switch off).
        newFeeTo;
        revert("NOT_IMPLEMENTED");
    }

    function mint(uint256 amount0, uint256 amount1, address to) external returns (uint256 liquidity) {
        // TODO: 1. _mintFee()  2. compute liquidity (first mint locks MINIMUM_LIQUIDITY)
        //       3. pull tokens, update reserves, mint shares  4. refresh kLast if the switch is on.
        amount0; amount1; to; liquidity;
        revert("NOT_IMPLEMENTED");
    }

    function burn(uint256 liquidity, address to) external returns (uint256 amount0, uint256 amount1) {
        // TODO: 1. validate  2. _mintFee()  3. pro-rata payout against the diluted supply
        //       4. burn shares, update reserves, pay out  5. refresh kLast if the switch is on.
        liquidity; to; amount0; amount1;
        revert("NOT_IMPLEMENTED");
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to)
        external
        returns (uint256 amountOut)
    {
        // TODO: constant-product swap with a 0.30% fee that stays in the reserves.
        tokenIn; amountIn; minAmountOut; to; amountOut;
        revert("NOT_IMPLEMENTED");
    }

    function _mintFee() internal returns (bool feeOn) {
        // TODO: if the switch is on and kLast != 0, mint
        //       totalSupply * (rootK - rootKLast) / (rootK * 5 + rootKLast) shares to feeTo.
        //       If the switch is off, reset kLast to zero.
        feeOn = false;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        // TODO: integer square root (floor).
        y;
        z = 0;
    }
}
