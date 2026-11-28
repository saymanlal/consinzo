# Address Book With Mapping Existence Checks

## Problem Statement

Implement `AddressBook` in `src/AddressBook.sol`. Every account owns a separate book. In its book
an account stores one non-empty text label per address, for example `0xB0B... => "Bob"`.

## Required Interface

```solidity
error ZeroAddress();
error EmptyLabel();
error EntryNotFound(address owner, address account);

event LabelSet(address indexed owner, address indexed account, string label);
event LabelRemoved(address indexed owner, address indexed account);

function setLabel(address account, string calldata label) external;
function removeLabel(address account) external;
function getLabel(address owner, address account) external view returns (string memory);
function hasLabel(address owner, address account) external view returns (bool);
function entryCount(address owner) external view returns (uint256);
```

## Rules

1. `setLabel(account, label)` writes into the caller's own book.
   - Revert with `ZeroAddress()` if `account == address(0)`.
   - Revert with `EmptyLabel()` if `label` has length zero.
   - Otherwise store the label (overwriting any previous one) and emit `LabelSet(msg.sender, account, label)`.
2. `removeLabel(account)` deletes the entry from the caller's own book and emits
   `LabelRemoved(msg.sender, account)`. Revert with `EntryNotFound(msg.sender, account)` if the
   caller has no entry for `account`.
3. `getLabel(owner, account)` returns the label that `owner` stored for `account`, or reverts with
   `EntryNotFound(owner, account)` if there is none.
4. `hasLabel(owner, account)` returns whether such an entry exists. It never reverts.
5. `entryCount(owner)` is the number of entries currently in `owner`'s book. Overwriting an entry
   does not change it; adding a new one increases it; removing one decreases it.
6. Books are independent. Nothing one account does may change another account's book.

## What the Tests Check

- Set, read, overwrite and remove, with `entryCount` staying correct throughout.
- Reads and removals of missing entries revert with `EntryNotFound` and the right arguments.
- Input validation for the zero address and the empty label.
- Isolation between two owners, and re-adding an entry after removal.
