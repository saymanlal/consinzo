// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract CreateAddressPredictor {
    error NonceTooHigh(uint256 nonce);

    /// @notice RLP encoding of `nonce` as an integer (shortest big-endian form).
    function encodeNonce(uint256 nonce) public pure returns (bytes memory out) {
        // EIP-2681 caps account nonces at 2^64 - 1.
        if (nonce > type(uint64).max) revert NonceTooHigh(nonce);

        // Zero is the empty byte string.
        if (nonce == 0) return hex"80";
        // A single byte below 0x80 is its own encoding.
        if (nonce < 0x80) return abi.encodePacked(uint8(nonce));

        // Count the significant bytes, then write them big-endian after the 0x80 + n prefix.
        uint256 length = 0;
        for (uint256 v = nonce; v != 0; v >>= 8) {
            ++length;
        }
        out = new bytes(length + 1);
        out[0] = bytes1(uint8(0x80 + length));
        for (uint256 i = 0; i < length; ++i) {
            // Byte i (from the most significant end) of the value.
            out[i + 1] = bytes1(uint8(nonce >> (8 * (length - 1 - i))));
        }
    }

    /// @notice RLP encoding of the list [deployer, nonce].
    function encodeDeployerAndNonce(address deployer, uint256 nonce) public pure returns (bytes memory) {
        bytes memory encodedNonce = encodeNonce(nonce);
        // Payload: 1 prefix byte + 20 address bytes + the encoded nonce (at most 9 bytes).
        // That is at most 30 bytes, so the short list form (0xc0 + length) always applies.
        uint256 payloadLength = 21 + encodedNonce.length;
        return abi.encodePacked(bytes1(uint8(0xc0 + payloadLength)), bytes1(0x94), deployer, encodedNonce);
    }

    /// @notice Address of the contract created by `deployer` at `nonce` with CREATE.
    function computeAddress(address deployer, uint256 nonce) external pure returns (address) {
        return address(uint160(uint256(keccak256(encodeDeployerAndNonce(deployer, nonce)))));
    }
}
