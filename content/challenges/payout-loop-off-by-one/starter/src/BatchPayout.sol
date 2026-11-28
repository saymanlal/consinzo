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

        // TODO: VULNERABLE. Check which indexes this loop actually visits.
        for (uint256 i = 0; i < count - 1; i++) {
            Payee memory p = payees[i];
            (bool ok, ) = p.account.call{value: p.amount}("");
            if (!ok) revert TransferFailed();
        }

        delete payees;
        totalOwed = 0;
    }
}
