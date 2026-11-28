// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract AddressSet {
    error IndexOutOfBounds(uint256 index, uint256 length);

    event Added(address indexed account);
    event Removed(address indexed account);

    address[] private _values;

    // account => position in _values, plus one. Zero means "not a member".
    // The offset is what allows position 0 and the member address(0) to be
    // represented without ambiguity.
    mapping(address => uint256) private _indexPlusOne;

    function add(address account) external returns (bool added) {
        if (_indexPlusOne[account] != 0) return false;

        _values.push(account);
        // After the push, length equals the new element's position plus one.
        _indexPlusOne[account] = _values.length;

        emit Added(account);
        return true;
    }

    function remove(address account) external returns (bool removed) {
        uint256 indexPlusOne = _indexPlusOne[account];
        if (indexPlusOne == 0) return false;

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = _values.length - 1;

        if (index != lastIndex) {
            // Move the last element into the hole and repoint its index.
            address last = _values[lastIndex];
            _values[index] = last;
            _indexPlusOne[last] = indexPlusOne;
        }

        _values.pop();
        // Deleted after the move so that removing the last element also clears it.
        delete _indexPlusOne[account];

        emit Removed(account);
        return true;
    }

    function contains(address account) external view returns (bool) {
        return _indexPlusOne[account] != 0;
    }

    function length() external view returns (uint256) {
        return _values.length;
    }

    function at(uint256 index) external view returns (address) {
        uint256 len = _values.length;
        if (index >= len) revert IndexOutOfBounds(index, len);
        return _values[index];
    }

    function values() external view returns (address[] memory) {
        return _values;
    }
}
