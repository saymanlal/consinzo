// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BitmapRegistry {
    address public owner;
    mapping(uint256 => uint256) private words;

    constructor() { owner = msg.sender; }

    function setFlag(uint256 index) external {
        require(msg.sender == owner, "ONLY_OWNER");
        words[index >> 8] |= (uint256(1) << (index & 0xff));
    }

    function clearFlag(uint256 index) external {
        require(msg.sender == owner, "ONLY_OWNER");
        words[index >> 8] &= ~(uint256(1) << (index & 0xff));
    }

    function hasFlag(uint256 index) external view returns (bool) {
        return (words[index >> 8] & (uint256(1) << (index & 0xff))) != 0;
    }
}