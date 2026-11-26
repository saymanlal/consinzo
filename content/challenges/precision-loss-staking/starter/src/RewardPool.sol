// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract RewardPool {
    uint256 public totalStaked;
    uint256 public totalReward;
    mapping(address => uint256) public stake;

    constructor(uint256 _totalReward) { totalReward = _totalReward; }

    function deposit(uint256 amount) external {
        require(amount > 0, "ZERO");
        stake[msg.sender] += amount;
        totalStaked += amount;
    }

    function earned(address user) public view returns (uint256) {
        if (totalStaked == 0) return 0;
        // VULNERABLE: Division before multiplication truncates to 0!
        return (stake[user] / totalStaked) * totalReward;
    }
}