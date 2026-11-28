# Role-based access control on NEAR

## Who is calling
A contract method learns its immediate caller from `near.predecessorAccountId()`. This is the account (user or contract) that sent the receipt. `near.signerAccountId()` is the account that signed the original transaction and stays the same along the whole call chain, so it must not be used for authorisation.

## Roles and role admins
A role is a named set of accounts. Each role has one admin role whose members may add and remove members. Using a role as the administrator (instead of a single owner account) allows several administrators and allows administration of different roles to be split between teams. The root role administers itself.

## Enumerable sets on top of key-value storage
NEAR contract storage is a key-value trie. `LookupMap` gives O(1) reads and writes but cannot list its keys. An enumerable set is usually built from two structures:

1. a vector of members, and
2. a map from member to its position in the vector.

Insertion appends to the vector. Deletion swaps the last element into the removed slot and pops. Both are O(1), at the cost of not preserving order on deletion.

## Pagination
View calls have gas limits, so a method that returns the whole member list eventually stops working. Offer `fromIndex` and `limit` parameters and return a bounded slice.

## Lock-out protection
If the last root admin removes itself, nobody can ever grant a role again. Guard the removal paths so the root role always keeps at least one member.
