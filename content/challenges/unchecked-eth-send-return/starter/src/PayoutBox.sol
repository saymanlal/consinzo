// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract PayoutBox {
    error ZeroDeposit();
    error NothingToWithdraw();
    error TransferFailed();

    mapping(address => uint256) public balances;

    function deposit() external payable {
        if (msg.value == 0) revert ZeroDeposit();
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        balances[msg.sender] = 0;

        // TODO: VULNERABLE. send() returns false on failure and the result is ignored,
        // so the balance above is wiped even when no ETH left the contract.
        payable(msg.sender).send(amount);
    }
}
