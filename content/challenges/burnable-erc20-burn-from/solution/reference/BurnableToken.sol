// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title BurnableToken
/// @notice Fixed initial supply; holders and approved spenders can burn.
contract BurnableToken {
    string public constant name = "Burnable Token";
    string public constant symbol = "BRN";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();

    constructor(uint256 initialSupply) {
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = balanceOf[msg.sender];
        if (balance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[msg.sender] = balance - amount;
            balanceOf[to] += amount; // bounded by totalSupply
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        uint256 allowed = allowance[account][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        // An unlimited approval is never decremented.
        if (allowed != type(uint256).max) {
            unchecked {
                allowance[account][msg.sender] = allowed - amount;
            }
        }
        _burn(account, amount);
    }

    /// @dev Removes `amount` from `account` and from the total supply.
    function _burn(address account, uint256 amount) internal {
        uint256 balance = balanceOf[account];
        if (balance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[account] = balance - amount;
            totalSupply -= amount; // totalSupply >= balance >= amount
        }
        emit Transfer(account, address(0), amount);
    }
}
