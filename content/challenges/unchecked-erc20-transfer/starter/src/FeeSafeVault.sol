// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IFeeERC20 {
    function balanceOf(address a) external view returns (uint256);
    function transfer(address to, uint256 amt) external returns (bool);
    function transferFrom(address from, address to, uint256 amt) external returns (bool);
}

contract FeeSafeVault {
    IFeeERC20 public immutable token;
    mapping(address => uint256) public balances;

    constructor(address _token) { token = IFeeERC20(_token); }

    function deposit(uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "PULL_FAILED");
        // VULNERABLE: Credits nominal amount instead of actual balance delta!
        balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "INSUFFICIENT");
        balances[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "SEND_FAILED");
    }
}