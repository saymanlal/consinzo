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
        // TODO: Reject address(0), check balance, move tokens, emit Transfer, return true
        revert("NOT_IMPLEMENTED");
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        // TODO: Reject address(0), overwrite the allowance, emit Approval, return true
        revert("NOT_IMPLEMENTED");
    }

    function burn(uint256 amount) external {
        // TODO: Destroy `amount` of the caller's tokens
        revert("NOT_IMPLEMENTED");
    }

    function burnFrom(address account, uint256 amount) external {
        // TODO: Consume the caller's allowance from `account` (keep type(uint256).max), then burn from `account`
        revert("NOT_IMPLEMENTED");
    }

}
