// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title WrappedEther
/// @notice Wraps Ether 1:1 into a transferable balance.
contract WrappedEther {
    string public constant name = "Wrapped Ether";
    string public constant symbol = "WETH";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Deposit(address indexed account, uint256 amount);
    event Withdrawal(address indexed account, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    error ZeroAddress();
    error InsufficientBalance();
    error EthTransferFailed();

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        uint256 balance = balanceOf[msg.sender];
        if (balance < amount) revert InsufficientBalance();

        // Effects before the external call: a re-entering caller sees the reduced balance.
        unchecked {
            balanceOf[msg.sender] = balance - amount;
            totalSupply -= amount; // totalSupply >= every individual balance
        }

        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert EthTransferFailed();

        emit Withdrawal(msg.sender, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = balanceOf[msg.sender];
        if (balance < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[msg.sender] = balance - amount;
        }
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }
}
