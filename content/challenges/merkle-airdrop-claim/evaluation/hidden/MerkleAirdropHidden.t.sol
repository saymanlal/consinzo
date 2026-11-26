// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MerkleAirdrop.sol";

contract MerkleAirdropHiddenTest is Test {
    MerkleAirdrop public airdrop;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    bytes32 public leaf0;
    bytes32 public leaf1;

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a <= b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function setUp() public {
        leaf0 = keccak256(abi.encodePacked(uint256(0), alice, uint256(1 ether)));
        leaf1 = keccak256(abi.encodePacked(uint256(1), bob, uint256(2 ether)));
        airdrop = new MerkleAirdrop{value: 3 ether}(_hashPair(leaf0, leaf1));
    }

    function testHiddenTamperedAmountRejected() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf1;
        vm.expectRevert();
        airdrop.claim(0, alice, 2 ether, proof);
    }

    function testHiddenTamperedRecipientRejected() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf1;
        vm.expectRevert();
        airdrop.claim(0, address(0xDEAD), 1 ether, proof);
    }
}
