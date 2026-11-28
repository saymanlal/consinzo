// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract AddressSet {
    error IndexOutOfBounds(uint256 index, uint256 length);

    event Added(address indexed account);
    event Removed(address indexed account);

    address[] private _values;

    // TODO: add a mapping that lets you find an address's position without a loop

    function add(address account) external returns (bool added) {
        // TODO: append if not a member; emit Added; return whether it was added
        revert("NOT_IMPLEMENTED");
    }

    function remove(address account) external returns (bool removed) {
        // TODO: swap-and-pop if a member; emit Removed; return whether it was removed
        revert("NOT_IMPLEMENTED");
    }

    function contains(address account) external view returns (bool) {
        // TODO
        return false;
    }

    function length() external view returns (uint256) {
        // TODO
        return 0;
    }

    function at(uint256 index) external view returns (address) {
        // TODO: revert with IndexOutOfBounds(index, length) when out of range
        return address(0);
    }

    function values() external view returns (address[] memory) {
        // TODO: all members in enumeration order
        return new address[](0);
    }
}
