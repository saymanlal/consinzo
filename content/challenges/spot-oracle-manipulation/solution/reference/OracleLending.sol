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
        uint256 spot = oracle.spotPrice();
        uint256 twap = oracle.twapPrice();
        require(twap > 0 && spot > 0, "INVALID_ORACLE");
        uint256 diff = spot > twap ? spot - twap : twap - spot;
        require((diff * 100) <= twap * 10, "ORACLE_DEVIATION");
        uint256 conservativePrice = spot < twap ? spot : twap;
        uint256 maxBorrow = (collateralEth[msg.sender] * conservativePrice * 50) / 100 / 1e18;
        require(debtUsd[msg.sender] + usdAmount <= maxBorrow, "UNDERCOLLATERALIZED");
        debtUsd[msg.sender] += usdAmount;
    }
}