// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract PoolViewGuard {
    uint256 public totalShares;
    uint256 private locked = 1;
    mapping(address => uint256) public shares;

    function deposit() external payable {
        require(msg.value > 0, "ZERO");
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
    }

    function sharePrice() public view returns (uint256) {
        if (totalShares == 0) return 1e18;
        return (address(this).balance * 1e18) / totalShares;
    }

    function withdraw(uint256 s) external {
        require(shares[msg.sender] >= s && s > 0, "BAD");
        uint256 payout = (s * address(this).balance) / totalShares;
        // VULNERABLE: ETH sent before shares burned, and sharePrice() readable while locked!
        (bool ok, ) = msg.sender.call{value: payout}("");
        require(ok);
        shares[msg.sender] -= s;
        totalShares -= s;
    }
}