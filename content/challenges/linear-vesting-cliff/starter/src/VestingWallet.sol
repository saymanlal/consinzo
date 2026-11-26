// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract VestingWallet {
    address public immutable beneficiary;
    uint256 public immutable start;
    uint256 public immutable cliff;
    uint256 public immutable duration;
    uint256 public released;

    constructor(address _beneficiary, uint256 _start, uint256 _cliffDuration, uint256 _duration) payable {
        beneficiary = _beneficiary;
        start = _start;
        cliff = _start + _cliffDuration;
        duration = _duration;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        revert("NOT_IMPLEMENTED");
    }

    function release() external returns (uint256 amount) {
        revert("NOT_IMPLEMENTED");
    }
}