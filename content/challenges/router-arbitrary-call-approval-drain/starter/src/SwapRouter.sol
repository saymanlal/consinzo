// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @notice Pulls `tokenIn` from the user, lets an external exchange perform the trade and
/// forwards whatever `tokenOut` arrived back to the user.
/// Users give this router a token approval once and then swap many times.
contract SwapRouter {
    error NotOwner();
    error ZeroAmount();
    error TargetNotAllowed();
    error SwapCallFailed();
    error InsufficientOutput();
    error TokenOperationFailed();

    event TargetSet(address indexed target, bool allowed);
    event Swapped(
        address indexed user,
        address indexed target,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    address public immutable owner;
    /// @notice Exchanges the owner has vetted.
    mapping(address => bool) public allowedTarget;

    constructor() {
        owner = msg.sender;
    }

    function setAllowedTarget(address target, bool allowed) external {
        if (msg.sender != owner) revert NotOwner();
        allowedTarget[target] = allowed;
        emit TargetSet(target, allowed);
    }

    /// @param target Exchange to call.
    /// @param data   Calldata for the exchange, built off-chain by the user's wallet.
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address target,
        bytes calldata data
    ) external returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        // TODO: `target` and `data` come straight from the caller.

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

        if (!IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn)) revert TokenOperationFailed();
        if (!IERC20(tokenIn).approve(target, amountIn)) revert TokenOperationFailed();

        (bool ok, ) = target.call(data);
        if (!ok) revert SwapCallFailed();

        // Never leave a standing allowance to the exchange.
        if (!IERC20(tokenIn).approve(target, 0)) revert TokenOperationFailed();

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
        if (amountOut < minAmountOut) revert InsufficientOutput();
        if (!IERC20(tokenOut).transfer(msg.sender, amountOut)) revert TokenOperationFailed();

        emit Swapped(msg.sender, target, tokenIn, tokenOut, amountIn, amountOut);
    }
}
