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

    function _pairFor(address tokenA, address tokenB) private view returns (IPair pair) {
        pair = IPair(factory.getPair(tokenA, tokenB));
        if (address(pair) == address(0)) revert PairNotFound();
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        uint256 n = path.length;
        if (n < 2) revert InvalidPath();
        amounts = new uint256[](n);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < n - 1; i++) {
            IPair pair = _pairFor(path[i], path[i + 1]);
            (uint256 r0, uint256 r1) = pair.getReserves();
            (uint256 reserveIn, uint256 reserveOut) = path[i] == pair.token0() ? (r0, r1) : (r1, r0);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        if (block.timestamp > deadline) revert Expired();
        amounts = getAmountsOut(amountIn, path);
        uint256 last = path.length - 1;
        if (amounts[last] < amountOutMin) revert InsufficientOutputAmount();

        // The user's tokens go straight into the first pair; the router never holds funds.
        address firstPair = factory.getPair(path[0], path[1]);
        if (!IERC20(path[0]).transferFrom(msg.sender, firstPair, amountIn)) revert TransferFailed();

        for (uint256 i = 0; i < last; i++) {
            IPair pair = _pairFor(path[i], path[i + 1]);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = path[i] == pair.token0()
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            // Output of this hop is the input of the next one, so it is sent there directly.
            address recipient = i + 1 < last ? factory.getPair(path[i + 1], path[i + 2]) : to;
            pair.swap(amount0Out, amount1Out, recipient);
        }

        emit Swapped(msg.sender, to, path[0], path[last], amountIn, amounts[last]);
    }
}
