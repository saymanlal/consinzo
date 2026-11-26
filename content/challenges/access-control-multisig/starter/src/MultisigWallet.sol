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

    receive() external payable {}

    constructor(address[] memory _owners, uint256 _required) {
        // TODO: Validate unique non-zero owners and 1 <= _required <= _owners.length
        owners = _owners;
        required = _required;
    }

    function submitTransaction(address to, uint256 value, bytes calldata data) external returns (uint256 txId) {
        revert("NOT_IMPLEMENTED");
    }

    function confirmTransaction(uint256 txId) external {
        revert("NOT_IMPLEMENTED");
    }

    function revokeConfirmation(uint256 txId) external {
        revert("NOT_IMPLEMENTED");
    }

    function executeTransaction(uint256 txId) external {
        revert("NOT_IMPLEMENTED");
    }
}
