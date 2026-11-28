// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title ConfirmationWallet
/// @notice M-of-N wallet: owners submit, confirm and execute arbitrary calls.
contract ConfirmationWallet {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    error NotOwner();
    error InvalidOwner();
    error DuplicateOwner();
    error InvalidThreshold();
    error TxNotFound();
    error AlreadyExecuted();
    error AlreadyConfirmed();
    error NotConfirmed();
    error BelowThreshold();
    error CallFailed();

    event Submitted(uint256 indexed txId, address indexed owner);
    event Confirmed(uint256 indexed txId, address indexed owner);
    event Revoked(uint256 indexed txId, address indexed owner);
    event Executed(uint256 indexed txId);

    mapping(address => bool) public isOwner;
    uint256 public ownerCount;
    uint256 public threshold;

    Transaction[] private _txs;
    mapping(uint256 => mapping(address => bool)) public confirmed;

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    constructor(address[] memory owners_, uint256 threshold_) {
        // TODO: the owner list and the threshold are not validated.
        for (uint256 i = 0; i < owners_.length; i++) {
            isOwner[owners_[i]] = true;
        }
        ownerCount = owners_.length;
        threshold = threshold_;
    }

    receive() external payable {}

    function submit(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256 txId) {
        txId = _txs.length;
        _txs.push(Transaction(to, value, data, false, 0));
        emit Submitted(txId, msg.sender);
    }

    function confirm(uint256 txId) external onlyOwner {
        Transaction storage t = _get(txId);
        if (t.executed) revert AlreadyExecuted();
        // TODO: nothing stops the same owner from confirming again and again.
        confirmed[txId][msg.sender] = true;
        t.confirmations += 1;
        emit Confirmed(txId, msg.sender);
    }

    function revoke(uint256 txId) external onlyOwner {
        Transaction storage t = _get(txId);
        if (t.executed) revert AlreadyExecuted();
        if (!confirmed[txId][msg.sender]) revert NotConfirmed();
        confirmed[txId][msg.sender] = false;
        t.confirmations -= 1;
        emit Revoked(txId, msg.sender);
    }

    function execute(uint256 txId) external onlyOwner {
        Transaction storage t = _get(txId);
        if (t.executed) revert AlreadyExecuted();
        if (t.confirmations < threshold) revert BelowThreshold();
        t.executed = true;
        (bool ok, ) = t.to.call{value: t.value}(t.data);
        if (!ok) revert CallFailed();
        emit Executed(txId);
    }

    function confirmationCount(uint256 txId) external view returns (uint256) {
        return _get(txId).confirmations;
    }

    function _get(uint256 txId) private view returns (Transaction storage) {
        if (txId >= _txs.length) revert TxNotFound();
        return _txs[txId];
    }
}
