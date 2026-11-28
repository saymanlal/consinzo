// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Whitelist {
    error NotOwner(address caller);
    error ZeroAddress();
    error NotAllowed(address caller);

    event Added(address indexed account);
    event Removed(address indexed account);
    event CheckedIn(address indexed account, uint256 count);

    address public immutable owner;
    uint256 public allowedCount;
    mapping(address => bool) public isAllowed;
    mapping(address => uint256) public checkIns;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier onlyAllowed() {
        if (!isAllowed[msg.sender]) revert NotAllowed(msg.sender);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function add(address account) external onlyOwner returns (bool changed) {
        return _add(account);
    }

    function remove(address account) external onlyOwner returns (bool changed) {
        return _remove(account);
    }

    function addBatch(address[] calldata accounts) external onlyOwner returns (uint256 added) {
        uint256 length = accounts.length;
        for (uint256 i = 0; i < length; i++) {
            // A zero address reverts inside _add, which rolls back the entire batch.
            if (_add(accounts[i])) added += 1;
        }
    }

    function removeBatch(address[] calldata accounts) external onlyOwner returns (uint256 removed) {
        uint256 length = accounts.length;
        for (uint256 i = 0; i < length; i++) {
            if (_remove(accounts[i])) removed += 1;
        }
    }

    function checkIn() external onlyAllowed {
        uint256 count = checkIns[msg.sender] + 1;
        checkIns[msg.sender] = count;
        emit CheckedIn(msg.sender, count);
    }

    /// @dev Returns true only when the account was not listed before, so the
    ///      counter and the event always reflect a real change.
    function _add(address account) internal returns (bool) {
        if (account == address(0)) revert ZeroAddress();
        if (isAllowed[account]) return false;

        isAllowed[account] = true;
        allowedCount += 1;
        emit Added(account);
        return true;
    }

    function _remove(address account) internal returns (bool) {
        if (!isAllowed[account]) return false;

        isAllowed[account] = false;
        allowedCount -= 1;
        emit Removed(account);
        return true;
    }
}
