// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract SigGuard {
    uint256 private constant SECP256K1_HALF_N =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    address public immutable signer;
    mapping(bytes32 => bool) public usedDigest;

    constructor(address _signer) { signer = _signer; }

    function verifyAndConsume(bytes32 digest, uint8 v, bytes32 r, bytes32 s) external {
        require(signer != address(0), "ZERO_SIGNER");
        require(!usedDigest[digest], "REPLAY");
        require(v == 27 || v == 28, "INVALID_V");
        require(uint256(s) <= SECP256K1_HALF_N, "MALLEABLE_S");
        address recovered = ecrecover(digest, v, r, s);
        require(recovered != address(0) && recovered == signer, "INVALID_SIGNER");
        usedDigest[digest] = true;
    }
}