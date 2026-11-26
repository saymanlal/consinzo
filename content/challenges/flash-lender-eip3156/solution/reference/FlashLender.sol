// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IFlashToken {
    function balanceOf(address a) external view returns (uint256);
    function transfer(address to, uint256 amt) external returns (bool);
    function transferFrom(address f, address t, uint256 amt) external returns (bool);
}

interface IERC3156Borrower {
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external returns (bytes32);
}

contract FlashLender {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    IFlashToken public immutable token;

    constructor(address _token) { token = IFlashToken(_token); }

    function flashFee(uint256 amount) public pure returns (uint256) {
        return (amount * 10) / 10_000;
    }

    function flashLoan(IERC3156Borrower receiver, uint256 amount, bytes calldata data) external returns (bool) {
        require(amount > 0 && token.balanceOf(address(this)) >= amount, "INSUFFICIENT_LIQUIDITY");
        uint256 fee = flashFee(amount);
        uint256 beforeBal = token.balanceOf(address(this));
        require(token.transfer(address(receiver), amount), "SEND_FAILED");
        require(receiver.onFlashLoan(msg.sender, address(token), amount, fee, data) == CALLBACK_SUCCESS, "BAD_CALLBACK");
        require(token.transferFrom(address(receiver), address(this), amount + fee), "REPAY_FAILED");
        require(token.balanceOf(address(this)) >= beforeBal + fee, "INVARIANT_FAILED");
        return true;
    }
}