# Todo List With a Struct Array

## Problem Statement

Implement `TodoList` in `src/TodoList.sol`. Every account has its own list of todo items. An item
has a text and a `done` flag. Items are never deleted, so an item's index never changes.

## Required Interface

```solidity
struct Todo {
    string text;
    bool done;
}

error EmptyText();
error IndexOutOfBounds(uint256 index, uint256 length);

event TodoAdded(address indexed owner, uint256 indexed index, string text);
event TodoToggled(address indexed owner, uint256 indexed index, bool done);

function add(string calldata text) external returns (uint256 index);
function toggle(uint256 index) external returns (bool done);
function get(address owner, uint256 index) external view returns (string memory text, bool done);
function count(address owner) external view returns (uint256);
function doneCount(address owner) external view returns (uint256);
```

## Rules

1. `add(text)` appends a new, not-done item to the caller's list and returns its index (the first
   item has index `0`). Revert with `EmptyText()` if `text` has length zero. Emit
   `TodoAdded(msg.sender, index, text)`.
2. `toggle(index)` flips the `done` flag of the caller's item at `index`, returns the new flag and
   emits `TodoToggled(msg.sender, index, done)`. Toggling twice restores the original state.
3. `get(owner, index)` returns the text and flag of `owner`'s item.
4. `toggle` and `get` revert with `IndexOutOfBounds(index, length)` when `index >= length`, where
   `length` is the number of items in the list concerned.
5. `count(owner)` is the number of items in `owner`'s list. `doneCount(owner)` is how many of them
   are currently done.
6. Lists are independent: an account can only modify its own list.

## What the Tests Check

- Indices returned by `add`, and the stored text and flag.
- `toggle` in both directions, with `doneCount` staying accurate.
- Out-of-bounds reads and toggles revert with the exact index and length.
- Two users with separate lists do not affect each other.
