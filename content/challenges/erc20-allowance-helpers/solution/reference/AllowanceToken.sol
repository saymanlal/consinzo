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
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        uint256 current = allowance[msg.sender][spender];
        // current + addedValue > max  <=>  addedValue > max - current (no overflow in the check)
        if (addedValue > type(uint256).max - current) revert AllowanceOverflow();
        unchecked {
            _approve(msg.sender, spender, current + addedValue);
        }
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 current = allowance[msg.sender][spender];
        if (subtractedValue > current) revert AllowanceUnderflow();
        unchecked {
            _approve(msg.sender, spender, current - subtractedValue);
        }
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        // A maximal allowance is the "infinite approval" convention: never decremented.
        if (allowed != type(uint256).max) {
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (spender == address(0)) revert ZeroAddress();
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = balanceOf[from];
        if (balance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = balance - amount;
            balanceOf[to] += amount; // bounded by totalSupply
        }
        emit Transfer(from, to, amount);
    }
}
