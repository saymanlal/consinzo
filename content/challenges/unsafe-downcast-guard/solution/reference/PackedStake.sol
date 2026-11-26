// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract PackedStake {
    struct StakeInfo {
        uint96 amount;
        uint64 updatedAt;
    }
    mapping(address => StakeInfo) public stakes;

    function deposit(uint256 amount) external {
        require(amount > 0, "ZERO");
        require(amount <= type(uint96).max, "UINT96_OVERFLOW");
        require(block.timestamp <= type(uint64).max, "UINT64_OVERFLOW");
        stakes[msg.sender] = StakeInfo({
            amount: uint96(amount),
            updatedAt: uint64(block.timestamp)
        });
    }
}