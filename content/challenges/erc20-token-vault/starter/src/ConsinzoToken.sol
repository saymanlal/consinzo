// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract ConsinzoToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        // TODO: Restrict to owner, disallow address(0), update totalSupply and balanceOf, emit Transfer
        revert("NOT_IMPLEMENTED");
    }

    function burn(uint256 amount) external {
        // TODO: Ensure sufficient balance, decrement balanceOf and totalSupply, emit Transfer to address(0)
        revert("NOT_IMPLEMENTED");
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        // TODO: Validate recipient and balance, move tokens, emit Transfer
        revert("NOT_IMPLEMENTED");
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        // TODO: Validate spender != address(0), set allowance, emit Approval
        revert("NOT_IMPLEMENTED");
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        // TODO: Validate allowance (preserve type(uint256).max), balance, and recipient; emit Transfer
        revert("NOT_IMPLEMENTED");
    }
}
