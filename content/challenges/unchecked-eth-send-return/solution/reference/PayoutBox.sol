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

        // Effect before interaction: a re-entrant call sees a zero balance.
        balances[msg.sender] = 0;

        // call forwards all remaining gas, so contract wallets can receive the payment.
        // Its success flag must be checked: reverting here also rolls back the zeroing
        // above, which leaves the user's claim intact.
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
