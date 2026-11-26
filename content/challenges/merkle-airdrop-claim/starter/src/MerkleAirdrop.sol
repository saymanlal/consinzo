// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MerkleAirdrop {
    bytes32 public immutable merkleRoot;
    mapping(uint256 => bool) public claimed;

    event Claimed(uint256 indexed index, address indexed account, uint256 amount);

    constructor(bytes32 _merkleRoot) payable {
        merkleRoot = _merkleRoot;
    }

    function verify(bytes32[] calldata proof, bytes32 leaf) public view returns (bool) {
        revert("NOT_IMPLEMENTED");
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata proof) external {
        revert("NOT_IMPLEMENTED");
    }
}
