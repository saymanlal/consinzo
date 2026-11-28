// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title CappedToken
/// @notice Owner-mintable token with an immutable ceiling on total supply.
contract CappedToken {
    string public constant name = "Capped Token";
    string public constant symbol = "CAP";
    uint8 public constant decimals = 18;

    address public immutable owner;
    uint256 public immutable cap;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    error ZeroCap();
    error NotOwner();
    error ZeroAddress();
    error CapExceeded();
    error InsufficientBalance();

    constructor(uint256 cap_) {
        if (cap_ == 0) revert ZeroCap();
        cap = cap_;
        owner = msg.sender;
    }

    function remainingMintable() public view returns (uint256) {
        // Invariant: totalSupply <= cap, so this never underflows.
        return cap - totalSupply;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        if (to == address(0)) revert ZeroAddress();
        // Compare with the remaining room instead of computing totalSupply + amount,
        // which would overflow (and panic) for very large amounts.
        if (amount > cap - totalSupply) revert CapExceeded();

        unchecked {
            // totalSupply + amount <= cap, and no balance can exceed totalSupply.
            totalSupply += amount;
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external {
        uint256 balance = balanceOf[msg.sender];
        if (balance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[msg.sender] = balance - amount;
            totalSupply -= amount;
        }
        emit Transfer(msg.sender, address(0), amount);
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
}
