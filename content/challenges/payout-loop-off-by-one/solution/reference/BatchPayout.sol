// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BatchPayout {
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error NoPayees();
    error InsufficientFunds();
    error TransferFailed();

    struct Payee {
        address account;
        uint256 amount;
    }

    address public immutable owner;
    Payee[] public payees;
    uint256 public totalOwed;

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function payeeCount() external view returns (uint256) {
        return payees.length;
    }

    function addPayee(address account, uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        if (account == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        payees.push(Payee(account, amount));
        totalOwed += amount;
    }

    function payAll() external {
        if (msg.sender != owner) revert NotOwner();
        uint256 count = payees.length;
        if (count == 0) revert NoPayees();
        if (address(this).balance < totalOwed) revert InsufficientFunds();

        // Copy the queue to memory and clear storage before any ETH leaves, so a payee
        // that calls back into this contract finds an empty queue.
        Payee[] memory batch = payees;
        delete payees;
        totalOwed = 0;

        // Half-open range [0, count): indexes 0 .. count - 1, each visited once.
        for (uint256 i = 0; i < count; i++) {
            (bool ok, ) = batch[i].account.call{value: batch[i].amount}("");
            if (!ok) revert TransferFailed();
        }
    }
}
