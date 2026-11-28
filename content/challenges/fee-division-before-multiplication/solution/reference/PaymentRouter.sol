// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract PaymentRouter {
    error FeeTooHigh();
    error ZeroAddress();
    error ZeroAmount();
    error NotTreasury();
    error NothingToWithdraw();
    error TransferFailed();

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000;

    address public immutable treasury;
    uint256 public immutable feeBps;
    uint256 public accruedFees;

    constructor(address treasury_, uint256 feeBps_) {
        if (treasury_ == address(0)) revert ZeroAddress();
        if (feeBps_ > MAX_FEE_BPS) revert FeeTooHigh();
        treasury = treasury_;
        feeBps = feeBps_;
    }

    /// @notice floor(amount * feeBps / BPS).
    /// @dev Multiply before dividing so the only rounding is the final floor, which
    ///      loses less than one wei. feeBps is at most 1_000, so the product can only
    ///      overflow for amounts above 2^256 / 1000, far beyond any ETH value; checked
    ///      arithmetic would revert in that case rather than wrap.
    function quoteFee(uint256 amount) public view returns (uint256) {
        return amount * feeBps / BPS;
    }

    function pay(address payee) external payable {
        if (msg.value == 0) revert ZeroAmount();
        if (payee == address(0)) revert ZeroAddress();

        uint256 fee = quoteFee(msg.value);
        accruedFees += fee;

        (bool ok, ) = payee.call{value: msg.value - fee}("");
        if (!ok) revert TransferFailed();
    }

    function withdrawFees() external {
        if (msg.sender != treasury) revert NotTreasury();
        uint256 amount = accruedFees;
        if (amount == 0) revert NothingToWithdraw();
        accruedFees = 0;
        (bool ok, ) = treasury.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
