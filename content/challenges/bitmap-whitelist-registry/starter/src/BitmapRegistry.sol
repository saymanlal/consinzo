// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BitmapRegistry {
    address public owner;
    mapping(uint256 => uint256) private words;

    constructor() { owner = msg.sender; }

    function setFlag(uint256 index) external {
        revert("NOT_IMPLEMENTED");
    }

    function clearFlag(uint256 index) external {
        revert("NOT_IMPLEMENTED");
    }

    function hasFlag(uint256 index) external view returns (bool) {
        revert("NOT_IMPLEMENTED");
    }
}