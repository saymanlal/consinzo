// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BloomFilter {
    error InvalidParameters();
    error InvalidHashIndex();
    error IndexOutOfRange();

    event ItemAdded(bytes32 indexed item, bool changed);

    uint256 public immutable bitCount;
    uint8 public immutable hashCount;
    uint256 public setBits;

    // TODO: declare the bitmap storage (256 bits per word).

    constructor(uint256 bitCount_, uint8 hashCount_) {
        // TODO: revert with InvalidParameters for bitCount_ == 0, hashCount_ == 0 or hashCount_ > 16.
        bitCount = bitCount_;
        hashCount = hashCount_;
    }

    function bitIndex(bytes32 item, uint8 i) public view returns (uint256) {
        // TODO: uint256(keccak256(abi.encodePacked(item, uint8(i)))) % bitCount, InvalidHashIndex for i >= hashCount.
        revert("NOT_IMPLEMENTED");
    }

    function add(bytes32 item) external returns (bool changed) {
        // TODO: set the k bits, keep setBits exact, emit ItemAdded.
        revert("NOT_IMPLEMENTED");
    }

    function mightContain(bytes32 item) external view returns (bool) {
        // TODO: true only if all k bits are set.
        return false;
    }

    function bitAt(uint256 index) external view returns (bool) {
        // TODO: IndexOutOfRange for index >= bitCount.
        revert("NOT_IMPLEMENTED");
    }

    function word(uint256 wordIndex) external view returns (uint256) {
        // TODO
        return 0;
    }
}
