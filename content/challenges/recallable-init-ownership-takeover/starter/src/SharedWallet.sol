// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract SharedWallet {
    error AlreadyInitialized();
    error NotOwner();
    error ZeroAddress();
    error InsufficientBalance();
    error TransferFailed();

    address public owner;
    bool public initialized;

    receive() external payable {}

    // TODO: VULNERABLE. Nothing stops this from being called a second time.
    function init(address owner_) external {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
        initialized = true;
    }

    function withdraw(address payable to, uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        if (to == address(0)) revert ZeroAddress();
        if (amount > address(this).balance) revert InsufficientBalance();
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
