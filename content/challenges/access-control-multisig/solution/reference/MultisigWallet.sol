// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MultisigWallet {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "NOT_OWNER");
        _;
    }

    receive() external payable {}

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "OWNERS_REQUIRED");
        require(_required > 0 && _required <= _owners.length, "INVALID_THRESHOLD");
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "ZERO_OWNER");
            require(!isOwner[owner], "DUPLICATE_OWNER");
            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    function submitTransaction(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256 txId) {
        require(to != address(0), "ZERO_TARGET");
        txId = transactions.length;
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0
        }));
    }

    function confirmTransaction(uint256 txId) external onlyOwner {
        require(txId < transactions.length, "TX_NOT_FOUND");
        Transaction storage txn = transactions[txId];
        require(!txn.executed, "ALREADY_EXECUTED");
        require(!isConfirmed[txId][msg.sender], "ALREADY_CONFIRMED");
        isConfirmed[txId][msg.sender] = true;
        txn.confirmations += 1;
    }

    function revokeConfirmation(uint256 txId) external onlyOwner {
        require(txId < transactions.length, "TX_NOT_FOUND");
        Transaction storage txn = transactions[txId];
        require(!txn.executed, "ALREADY_EXECUTED");
        require(isConfirmed[txId][msg.sender], "NOT_CONFIRMED");
        isConfirmed[txId][msg.sender] = false;
        txn.confirmations -= 1;
    }

    function executeTransaction(uint256 txId) external onlyOwner {
        require(txId < transactions.length, "TX_NOT_FOUND");
        Transaction storage txn = transactions[txId];
        require(!txn.executed, "ALREADY_EXECUTED");
        require(txn.confirmations >= required, "INSUFFICIENT_CONFIRMATIONS");
        txn.executed = true;
        (bool ok, ) = txn.to.call{value: txn.value}(txn.data);
        require(ok, "EXECUTION_FAILED");
    }
}
