// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract SignedEscrow {
    address public immutable expectedSigner;
    mapping(address => uint256) public nonces;

    constructor(address _signer) payable {
        expectedSigner = _signer;
    }

    function computeDigest(address recipient, uint256 amount, uint256 nonce) public view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this), recipient, amount, nonce));
    }

    function claimWithSig(
        address recipient,
        uint256 amount,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(expectedSigner != address(0), "ZERO_SIGNER");
        require(recipient != address(0), "ZERO_RECIPIENT");
        require(nonce == nonces[expectedSigner], "INVALID_NONCE");

        bytes32 digest = computeDigest(recipient, amount, nonce);
        bytes32 ethSigned = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        address recovered = ecrecover(ethSigned, v, r, s);
        require(recovered != address(0) && recovered == expectedSigner, "INVALID_SIG");

        nonces[expectedSigner] += 1;
        (bool ok, ) = recipient.call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
    }
}
