// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract CommitRaffle {
    mapping(address => bytes32) public commitments;
    mapping(address => uint256) public commitBlock;
    address public lastWinner;

    function play(uint256 guess) external {
        // VULNERABLE: Same-tx resolution via block.timestamp is gameable!
        uint256 draw = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 10;
        if (guess == draw) lastWinner = msg.sender;
    }

    function commit(bytes32 commitment) external {
        commitments[msg.sender] = commitment;
        commitBlock[msg.sender] = block.number;
    }

    function reveal(uint256 secret) external {
        revert("NOT_IMPLEMENTED");
    }
}