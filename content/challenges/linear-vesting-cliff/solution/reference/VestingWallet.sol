// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract VestingWallet {
    address public immutable beneficiary;
    uint256 public immutable start;
    uint256 public immutable cliff;
    uint256 public immutable duration;
    uint256 public released;

    constructor(address _beneficiary, uint256 _start, uint256 _cliffDuration, uint256 _duration) payable {
        require(_beneficiary != address(0) && _duration > 0 && _cliffDuration <= _duration, "INVALID_PARAMS");
        beneficiary = _beneficiary;
        start = _start;
        cliff = _start + _cliffDuration;
        duration = _duration;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        uint256 total = address(this).balance + released;
        if (timestamp < cliff) return 0;
        if (timestamp >= start + duration) return total;
        return (total * (timestamp - start)) / duration;
    }

    function release() external returns (uint256 amount) {
        require(msg.sender == beneficiary, "ONLY_BENEFICIARY");
        amount = vestedAmount(block.timestamp) - released;
        require(amount > 0, "NOTHING_DUE");
        released += amount;
        (bool ok, ) = beneficiary.call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
    }
}