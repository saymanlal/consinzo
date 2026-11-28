// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Whitelist {
    error NotOwner(address caller);
    error ZeroAddress();
    error NotAllowed(address caller);

    event Added(address indexed account);
    event Removed(address indexed account);
    event CheckedIn(address indexed account, uint256 count);

    address public owner;
    uint256 public allowedCount;
    mapping(address => bool) public isAllowed;
    mapping(address => uint256) public checkIns;

    constructor() {
        // TODO: the deployer is the owner
    }

    function add(address account) external returns (bool changed) {
        // TODO: owner only; reject address(0); list the account if it is not listed yet
        revert("NOT_IMPLEMENTED");
    }

    function remove(address account) external returns (bool changed) {
        // TODO: owner only; unlist the account if it is listed
        revert("NOT_IMPLEMENTED");
    }

    function addBatch(address[] calldata accounts) external returns (uint256 added) {
        // TODO: owner only; apply the add rule to every element; count the new entries
        revert("NOT_IMPLEMENTED");
    }

    function removeBatch(address[] calldata accounts) external returns (uint256 removed) {
        // TODO: owner only; apply the remove rule to every element; count the removals
        revert("NOT_IMPLEMENTED");
    }

    function checkIn() external {
        // TODO: only listed callers; bump checkIns[msg.sender]; emit CheckedIn
        revert("NOT_IMPLEMENTED");
    }
}
