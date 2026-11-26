// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IGovToken {
    function balanceOf(address a) external view returns (uint256);
    function transferFrom(address f, address t, uint256 amt) external returns (bool);
}

contract SnapshotDAO {
    IGovToken public immutable token;
    mapping(uint256 => uint256) public yesVotes;
    mapping(uint256 => uint256) public proposalBlock;
    mapping(address => uint256) public lockedPower;
    mapping(address => uint256) public lockedAtBlock;
    mapping(uint256 => mapping(address => bool)) public voted;
    uint256 public nextId;

    constructor(address _token) { token = IGovToken(_token); }

    function lockVotes(uint256 amount) external {
        require(amount > 0, "ZERO");
        require(token.transferFrom(msg.sender, address(this), amount), "PULL");
        lockedPower[msg.sender] += amount;
        lockedAtBlock[msg.sender] = block.number;
    }

    function createProposal() external returns (uint256 id) {
        id = nextId++;
        proposalBlock[id] = block.number;
    }

    function vote(uint256 id) external {
        require(id < nextId, "BAD_ID");
        require(!voted[id][msg.sender], "ALREADY_VOTED");
        require(lockedPower[msg.sender] > 0, "NO_POWER");
        require(lockedAtBlock[msg.sender] < proposalBlock[id], "LOCKED_AFTER_PROPOSAL");
        voted[id][msg.sender] = true;
        yesVotes[id] += lockedPower[msg.sender];
    }
}