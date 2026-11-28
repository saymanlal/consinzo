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

    function init(address owner_) external {
        // One-shot guard. It is checked before anything else so that no caller, not
        // even the current owner, can run the setup logic twice.
        if (initialized) revert AlreadyInitialized();
        if (owner_ == address(0)) revert ZeroAddress();

        initialized = true;
        owner = owner_;
    }

    function withdraw(address payable to, uint256 amount) external {
        // Before initialisation owner is address(0), which can never be msg.sender,
        // so this check also covers the uninitialised state.
        if (msg.sender != owner) revert NotOwner();
        if (to == address(0)) revert ZeroAddress();
        if (amount > address(this).balance) revert InsufficientBalance();
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
