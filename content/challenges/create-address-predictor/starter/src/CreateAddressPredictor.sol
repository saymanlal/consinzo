// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract CreateAddressPredictor {
    error NonceTooHigh(uint256 nonce);

    /// @notice RLP encoding of `nonce` as an integer (shortest big-endian form).
    function encodeNonce(uint256 nonce) public pure returns (bytes memory) {
        // TODO: revert with NonceTooHigh when nonce > type(uint64).max.
        // TODO: 0 -> 0x80, 1..0x7f -> the byte itself, otherwise 0x80 + n followed by n bytes.
        revert("NOT_IMPLEMENTED");
    }

    /// @notice RLP encoding of the list [deployer, nonce].
    function encodeDeployerAndNonce(address deployer, uint256 nonce) public pure returns (bytes memory) {
        // TODO: list prefix, 0x94, the 20 address bytes, then encodeNonce(nonce).
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Address of the contract created by `deployer` at `nonce` with CREATE.
    function computeAddress(address deployer, uint256 nonce) external pure returns (address) {
        // TODO: last 20 bytes of keccak256(encodeDeployerAndNonce(deployer, nonce)).
        revert("NOT_IMPLEMENTED");
    }
}
