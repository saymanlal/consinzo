// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract EIP712Verifier {
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant ORDER_TYPEHASH =
        keccak256("Order(address maker,uint256 amount,uint256 nonce)");

    bytes32 public immutable nameHash;
    bytes32 public immutable versionHash;

    constructor(string memory name, string memory version) {
        nameHash = keccak256(bytes(name));
        versionHash = keccak256(bytes(version));
    }

    function domainSeparator() public view returns (bytes32) {
        revert("NOT_IMPLEMENTED");
    }

    function hashOrder(address maker, uint256 amount, uint256 nonce) public pure returns (bytes32) {
        revert("NOT_IMPLEMENTED");
    }

    function computeTypedDigest(bytes32 structHash) public view returns (bytes32) {
        revert("NOT_IMPLEMENTED");
    }
}