// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract RewardToken {
    error NotOwner();
    error ZeroAddress();
    error InsufficientBalance();

    address public owner;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    /// @dev Single place for the privilege check, shared by every owner-only function.
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) external onlyOwner {
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

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
}
