// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract TodoList {
    struct Todo {
        string text;
        bool done;
    }

    error EmptyText();
    error IndexOutOfBounds(uint256 index, uint256 length);

    event TodoAdded(address indexed owner, uint256 indexed index, string text);
    event TodoToggled(address indexed owner, uint256 indexed index, bool done);

    mapping(address => Todo[]) private _todos;
    mapping(address => uint256) public doneCount;

    function add(string calldata text) external returns (uint256 index) {
        // TODO: reject empty text, append to msg.sender's list, emit TodoAdded, return the index
        revert("NOT_IMPLEMENTED");
    }

    function toggle(uint256 index) external returns (bool done) {
        // TODO: bounds check, flip the flag in storage, keep doneCount correct, emit TodoToggled
        revert("NOT_IMPLEMENTED");
    }

    function get(address owner, uint256 index) external view returns (string memory text, bool done) {
        // TODO: bounds check, then return the item's fields
        return ("", false);
    }

    function count(address owner) external view returns (uint256) {
        // TODO: return the number of items in owner's list
        return 0;
    }
}
