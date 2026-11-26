// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract SigGuard {
    address public immutable signer;
    mapping(bytes32 => bool) public usedSignature;

    constructor(address _signer) { signer = _signer; }

    function verifyAndConsume(bytes32 digest, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 sigHash = keccak256(abi.encodePacked(v, r, s));
        require(!usedSignature[sigHash], "REPLAY");
        address recovered = ecrecover(digest, v, r, s);
        require(recovered == signer, "INVALID_SIGNER");
        usedSignature[sigHash] = true;
    }
}