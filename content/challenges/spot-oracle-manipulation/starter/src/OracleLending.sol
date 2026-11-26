// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPriceSource {
    function spotPrice() external view returns (uint256);
    function twapPrice() external view returns (uint256);
}

contract OracleLending {
    IPriceSource public immutable oracle;
    mapping(address => uint256) public collateralEth;
    mapping(address => uint256) public debtUsd;

    constructor(address _oracle) { oracle = IPriceSource(_oracle); }

    function depositCollateral() external payable {
        collateralEth[msg.sender] += msg.value;
    }

    function borrow(uint256 usdAmount) external {
        // VULNERABLE: Trusts instantaneous spotPrice without TWAP deviation check!
        uint256 price = oracle.spotPrice();
        uint256 maxBorrow = (collateralEth[msg.sender] * price * 50) / 100 / 1e18;
        require(debtUsd[msg.sender] + usdAmount <= maxBorrow, "UNDERCOLLATERALIZED");
        debtUsd[msg.sender] += usdAmount;
    }
}