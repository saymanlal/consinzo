// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract PoolViewGuard {
    uint256 public totalShares;
    uint256 private locked = 1;
    mapping(address => uint256) public shares;

    function deposit() external payable {
        require(locked == 1, "LOCKED");
        require(msg.value > 0, "ZERO");
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
    }

    function sharePrice() public view returns (uint256) {
        require(locked == 1, "REENTRANCY_LOCKED");
        if (totalShares == 0) return 1e18;
        return (address(this).balance * 1e18) / totalShares;
    }

    function withdraw(uint256 s) external {
        require(locked == 1, "LOCKED");
        locked = 2;
        require(shares[msg.sender] >= s && s > 0, "BAD");
        uint256 payout = (s * address(this).balance) / totalShares;
        shares[msg.sender] -= s;
        totalShares -= s;
        (bool ok, ) = msg.sender.call{value: payout}("");
        require(ok);
        locked = 1;
    }
}