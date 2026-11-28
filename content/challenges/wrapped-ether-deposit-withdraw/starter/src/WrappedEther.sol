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
        // TODO: Behave exactly like deposit()
        revert("NOT_IMPLEMENTED");
    }

    function deposit() public payable {
        // TODO: Credit msg.value to msg.sender and totalSupply, emit Deposit
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 amount) external {
        // TODO: Check balance, burn `amount`, send the Ether, emit Withdrawal
        revert("NOT_IMPLEMENTED");
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        // TODO: Validate recipient and balance, move the balance, emit Transfer, return true
        revert("NOT_IMPLEMENTED");
    }
}
