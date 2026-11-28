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

    // wordIndex => 256 bits. Bit n is word n / 256, position n % 256 (LSB = 0).
    mapping(uint256 => uint256) private _words;

    constructor(uint256 bitCount_, uint8 hashCount_) {
        if (bitCount_ == 0 || hashCount_ == 0 || hashCount_ > 16) revert InvalidParameters();
        bitCount = bitCount_;
        hashCount = hashCount_;
    }

    function bitIndex(bytes32 item, uint8 i) public view returns (uint256) {
        if (i >= hashCount) revert InvalidHashIndex();
        return _bitIndex(item, i);
    }

    function add(bytes32 item) external returns (bool changed) {
        uint256 k = hashCount;
        uint256 newlySet = 0;
        for (uint256 i = 0; i < k; ++i) {
            uint256 index = _bitIndex(item, i);
            uint256 mask = uint256(1) << (index & 0xff);
            // Read the word from storage on every round: two positions of the same item may
            // be the same bit, and that bit must be counted only once.
            uint256 current = _words[index >> 8];
            if (current & mask == 0) {
                _words[index >> 8] = current | mask;
                ++newlySet;
            }
        }
        if (newlySet != 0) {
            setBits += newlySet;
            changed = true;
        }
        emit ItemAdded(item, changed);
    }

    function mightContain(bytes32 item) external view returns (bool) {
        uint256 k = hashCount;
        for (uint256 i = 0; i < k; ++i) {
            uint256 index = _bitIndex(item, i);
            if (_words[index >> 8] & (uint256(1) << (index & 0xff)) == 0) return false;
        }
        return true;
    }

    function bitAt(uint256 index) external view returns (bool) {
        if (index >= bitCount) revert IndexOutOfRange();
        return _words[index >> 8] & (uint256(1) << (index & 0xff)) != 0;
    }

    function word(uint256 wordIndex) external view returns (uint256) {
        return _words[wordIndex];
    }

    function _bitIndex(bytes32 item, uint256 i) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(item, uint8(i)))) % bitCount;
    }
}
