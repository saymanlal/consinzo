# Enums and State Machines: Background

## Enums

```solidity
enum Status { None, Created, Paid, Shipped, Delivered }
```

An enum is a user-defined type with a fixed list of members. It is stored as a `uint8` holding the
member's position, starting at 0. The first member is therefore the default value of any unset
storage slot. Convert explicitly with `uint256(status)` when a number is needed. In the ABI an enum
is encoded like a `uint8`.

## State machines

A contract is a state machine when its functions are valid only in certain states and move the
contract (or one of its records) to another state. The rules are easiest to verify when each
function names exactly one state it accepts:

```solidity
if (current != expected) revert InvalidState(current);
order.status = next;
```

Avoid ordering comparisons such as `status >= Paid`: they silently admit states that were added
later or were never meant to qualify.

## Structs in mappings

`mapping(uint256 => Order)` stores one record per id. A `storage` reference
(`Order storage order = _orders[id];`) reads and writes the record in place without copying it.
An `address` and a `uint8` enum fit in one storage slot.

## Check order

When several checks can fail at once, the order decides which error the caller sees. Specifying
and following a fixed order makes the contract predictable for integrators.
