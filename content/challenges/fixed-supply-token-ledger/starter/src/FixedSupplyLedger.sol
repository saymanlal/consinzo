// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title FixedSupplyLedger
/// @notice A token whose whole supply is minted to the deployer at construction.
contract FixedSupplyLedger {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    error ZeroAddress();
    error InsufficientBalance();

    constructor(string memory name_, string memory symbol_, uint256 initialSupply) {
        // TODO: Store metadata, mint initialSupply to msg.sender, emit Transfer from address(0)
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        // TODO: Reject address(0), check the caller's balance, move tokens, emit Transfer, return true
        revert("NOT_IMPLEMENTED");
    }
}
