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
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 p = proof[i];
            computed = computed <= p
                ? keccak256(abi.encodePacked(computed, p))
                : keccak256(abi.encodePacked(p, computed));
        }
        return computed == merkleRoot;
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata proof) external {
        require(!claimed[index], "ALREADY_CLAIMED");
        require(account != address(0), "ZERO_ACCOUNT");
        bytes32 leaf = keccak256(abi.encodePacked(index, account, amount));
        require(verify(proof, leaf), "INVALID_PROOF");

        claimed[index] = true;
        (bool ok, ) = account.call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
        emit Claimed(index, account, amount);
    }
}
