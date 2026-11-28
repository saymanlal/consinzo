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
    // Kept as a running counter so reading it never requires a loop over the list.
    mapping(address => uint256) public doneCount;

    function add(string calldata text) external returns (uint256 index) {
        if (bytes(text).length == 0) revert EmptyText();

        Todo[] storage list = _todos[msg.sender];
        index = list.length;
        list.push(Todo({text: text, done: false}));

        emit TodoAdded(msg.sender, index, text);
    }

    function toggle(uint256 index) external returns (bool done) {
        Todo[] storage list = _todos[msg.sender];
        if (index >= list.length) revert IndexOutOfBounds(index, list.length);

        // Storage reference: the write below changes the stored item, not a copy.
        Todo storage item = list[index];
        done = !item.done;
        item.done = done;

        if (done) {
            doneCount[msg.sender] += 1;
        } else {
            doneCount[msg.sender] -= 1;
        }

        emit TodoToggled(msg.sender, index, done);
    }

    function get(address owner, uint256 index) external view returns (string memory text, bool done) {
        Todo[] storage list = _todos[owner];
        if (index >= list.length) revert IndexOutOfBounds(index, list.length);

        Todo storage item = list[index];
        return (item.text, item.done);
    }

    function count(address owner) external view returns (uint256) {
        return _todos[owner].length;
    }
}
