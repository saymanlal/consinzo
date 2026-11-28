// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title AllowanceToken
/// @notice ERC-20 with relative allowance adjustments and infinite approvals.
contract AllowanceToken {
    string public constant name = "Allowance Token";
    string public constant symbol = "ALW";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error AllowanceOverflow();
    error AllowanceUnderflow();

    constructor(uint256 initialSupply) {
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        // TODO: Reject address(0), check balance, move tokens, emit Transfer, return true
        revert("NOT_IMPLEMENTED");
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        // TODO: Reject address(0), overwrite the allowance, emit Approval, return true
        revert("NOT_IMPLEMENTED");
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        // TODO: Add to the current allowance; revert with AllowanceOverflow() instead of wrapping
        revert("NOT_IMPLEMENTED");
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        // TODO: Subtract from the current allowance; revert with AllowanceUnderflow() if it would go below zero
        revert("NOT_IMPLEMENTED");
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        // TODO: Check allowance first; leave type(uint256).max untouched, otherwise decrement; then transfer
        revert("NOT_IMPLEMENTED");
    }

}
