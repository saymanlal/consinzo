# Enumerable Address Set With Swap-and-Pop

## Problem Statement

Implement `AddressSet` in `src/AddressSet.sol`: a set of addresses that supports membership tests,
enumeration, and removal, all without loops in the mutating functions.

A mapping alone gives O(1) membership but cannot be enumerated. An array alone can be enumerated
but needs a scan to find an element. Combine both: an array of members plus a mapping from address
to its position. Remove with *swap-and-pop*: move the last element into the vacated position and
shrink the array by one.

## Required Interface

```solidity
error IndexOutOfBounds(uint256 index, uint256 length);

event Added(address indexed account);
event Removed(address indexed account);

function add(address account) external returns (bool added);
function remove(address account) external returns (bool removed);
function contains(address account) external view returns (bool);
function length() external view returns (uint256);
function at(uint256 index) external view returns (address);
function values() external view returns (address[] memory);
```

## Rules

1. Anyone may call `add` and `remove`; this challenge is about the data structure.
2. `add(account)` appends the address at the end of the enumeration if it is not a member, emits
   `Added(account)` and returns `true`. If it is already a member it changes nothing and returns
   `false`. Every address is a valid element, **including `address(0)`**.
3. `remove(account)`, when the address is a member:
   - moves the element that is currently **last** in the enumeration into the removed element's
     position (if the removed element is itself last, nothing moves);
   - shrinks the enumeration by one;
   - emits `Removed(account)` and returns `true`.
   When the address is not a member it changes nothing and returns `false`.
4. `contains(account)` reports membership. `length()` is the number of members.
5. `at(index)` returns the member at that position and reverts with
   `IndexOutOfBounds(index, length)` when `index >= length()`.
6. `values()` returns all members in enumeration order.
7. `add` and `remove` must not loop over the members.

## Example

```
add A, add B, add C, add D   -> [A, B, C, D]
remove A                     -> [D, B, C]      (D moved into position 0)
remove D                     -> [C, B]         (C moved into position 0)
add A                        -> [C, B, A]
```

## What the Tests Check

- Membership, length and the exact enumeration order after sequences of adds and removes.
- Removing the first, a middle, the last and the only element.
- Removing an element that was previously moved by another removal.
- Duplicates, non-members and `address(0)` as a member.
- `at` bounds checking.
