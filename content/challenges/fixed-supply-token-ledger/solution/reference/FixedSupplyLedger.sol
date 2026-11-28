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
        name = name_;
        symbol = symbol_;
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();

        uint256 fromBalance = balanceOf[msg.sender];
        if (fromBalance < amount) revert InsufficientBalance();

        // Write the debit before reading the recipient's slot so that a self-transfer
        // (to == msg.sender) nets out to no change instead of minting `amount`.
        unchecked {
            balanceOf[msg.sender] = fromBalance - amount;
        }
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }
}
