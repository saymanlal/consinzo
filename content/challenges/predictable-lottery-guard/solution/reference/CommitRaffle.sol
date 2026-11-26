// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract CommitRaffle {
    mapping(address => bytes32) public commitments;
    mapping(address => uint256) public commitBlock;
    address public lastWinner;

    function commit(bytes32 commitment) external {
        require(commitment != bytes32(0), "ZERO_COMMITMENT");
        commitments[msg.sender] = commitment;
        commitBlock[msg.sender] = block.number;
    }

    function reveal(uint256 secret) external {
        bytes32 expected = commitments[msg.sender];
        require(expected != bytes32(0), "NO_COMMIT");
        require(block.number > commitBlock[msg.sender], "SAME_BLOCK");
        require(keccak256(abi.encodePacked(secret)) == expected, "INVALID_SECRET");
        delete commitments[msg.sender];
        if (secret % 10 == block.number % 10) {
            lastWinner = msg.sender;
        }
    }
}