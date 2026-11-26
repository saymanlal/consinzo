// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract VulnerableVault {
    mapping(address => uint256) public balances;
    uint256 private locked = 1;

    modifier nonReentrant() {
        require(locked == 1, "REENTRANCY_GUARD");
        locked = 2;
        _;
        locked = 1;
    }

    function deposit() external payable {
        require(msg.value > 0, "ZERO_DEPOSIT");
        balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 bal = balances[msg.sender];
        require(bal > 0, "NOTHING_TO_WITHDRAW");

        // Effect before interaction
        balances[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: bal}("");
        require(ok, "TRANSFER_FAILED");
    }

    function vaultBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
