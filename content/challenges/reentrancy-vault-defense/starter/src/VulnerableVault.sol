// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract VulnerableVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        require(msg.value > 0, "ZERO_DEPOSIT");
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 bal = balances[msg.sender];
        require(bal > 0, "NOTHING_TO_WITHDRAW");

        // VULNERABLE: External interaction happens before state effect!
        (bool ok, ) = msg.sender.call{value: bal}("");
        require(ok, "TRANSFER_FAILED");

        balances[msg.sender] = 0;
    }

    function vaultBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
