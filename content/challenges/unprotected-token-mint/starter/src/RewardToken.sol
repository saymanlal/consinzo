// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract RewardToken {
    error NotOwner();
    error ZeroAddress();
    error InsufficientBalance();

    address public owner;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor() {
        owner = msg.sender;
    }

    // TODO: VULNERABLE. Anyone can call this and create tokens for themselves.
    function mint(address to, uint256 amount) external {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) revert NotOwner();
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
}
