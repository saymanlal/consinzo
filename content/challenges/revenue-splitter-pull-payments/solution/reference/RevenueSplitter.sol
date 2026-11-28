// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract RevenueSplitter {
    error InvalidPayees();
    error ZeroAddress();
    error ZeroShares();
    error DuplicatePayee();
    error NotPayee();
    error NothingDue();
    error TransferFailed();

    event PaymentReceived(address indexed from, uint256 amount);
    event PaymentReleased(address indexed to, uint256 amount);

    uint256 public totalShares;
    uint256 public totalReleased;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public released;
    address[] internal payees;

    constructor(address[] memory payees_, uint256[] memory shares_) payable {
        uint256 n = payees_.length;
        if (n == 0 || n != shares_.length) revert InvalidPayees();
        uint256 total;
        for (uint256 i = 0; i < n; i++) {
            address account = payees_[i];
            uint256 share = shares_[i];
            if (account == address(0)) revert ZeroAddress();
            if (share == 0) revert ZeroShares();
            // A registered payee always has a non-zero share, so this detects duplicates.
            if (shares[account] != 0) revert DuplicatePayee();
            shares[account] = share;
            payees.push(account);
            total += share;
        }
        totalShares = total;
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function payeeCount() external view returns (uint256) {
        return payees.length;
    }

    function payee(uint256 index) external view returns (address) {
        return payees[index];
    }

    function totalReceived() public view returns (uint256) {
        return address(this).balance + totalReleased;
    }

    function releasable(address account) public view returns (uint256) {
        return (totalReceived() * shares[account]) / totalShares - released[account];
    }

    function release(address account) external returns (uint256 amount) {
        if (shares[account] == 0) revert NotPayee();
        amount = releasable(account);
        if (amount == 0) revert NothingDue();

        // Effects first: a re-entrant release() sees the payment as already made.
        released[account] += amount;
        totalReleased += amount;

        (bool ok, ) = account.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit PaymentReleased(account, amount);
    }
}
