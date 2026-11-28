# ERC-7201 Namespaced Storage Across Modules

## Problem Statement

Contracts that run behind proxies, or that are assembled from several modules, cannot
rely on Solidity's default layout where variables are numbered 0, 1, 2, ... in declaration
order: two modules would claim the same slots, and inserting a variable in an upgrade
shifts everything after it. ERC-7201 gives every module a *namespace* and derives a
far-away base slot from the namespace id. The module keeps all its state in one struct
rooted at that slot.

Implement `NamespacedApp` in `src/NamespacedApp.sol`. It has two modules, an ownership
module and a counter module, and keeps no state outside their namespaces.

## Namespaces and Layout

The location of a namespace is

```
keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff))
```

| namespace id | struct (members in this order) |
| --- | --- |
| `consinzo.storage.Ownable` | `address owner; address pendingOwner;` |
| `consinzo.storage.Counter` | `uint256 total; uint256 limit; mapping(address => uint256) perUser;` |

Each member occupies its own slot, starting at the namespace location: `owner` is at
`location`, `pendingOwner` at `location + 1`; `total` at `location`, `limit` at
`location + 1`, and the mapping uses base slot `location + 2` (so the entry of `user` is at
`keccak256(abi.encode(user, location + 2))`).

## Required Interface

```solidity
error AlreadyInitialized();
error ZeroAddress();
error NotOwner();
error NotPendingOwner();
error LimitReached();

event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
event Incremented(address indexed account, uint256 newTotal);
event LimitSet(uint256 limit);

function namespaceSlot(string calldata id) external pure returns (bytes32);
function readSlot(bytes32 slot) external view returns (bytes32);   // provided in the starter

// ownership module
function initialize(address initialOwner) external;
function owner() external view returns (address);
function pendingOwner() external view returns (address);
function transferOwnership(address newOwner) external;
function acceptOwnership() external;

// counter module
function increment() external returns (uint256 newTotal);
function setLimit(uint256 newLimit) external;
function total() external view returns (uint256);
function limit() external view returns (uint256);
function countOf(address account) external view returns (uint256);
```

## Rules

1. `namespaceSlot(id)` returns the ERC-7201 location for any id.
2. `initialize` sets the owner once. It reverts with `ZeroAddress()` for the zero address
   and with `AlreadyInitialized()` if an owner is already set. There is no constructor
   logic, because the contract is meant to be used through `delegatecall`.
3. Ownership transfer has two steps. `transferOwnership(newOwner)` (owner only, otherwise
   `NotOwner()`) records the pending owner; passing the zero address cancels a pending
   transfer. `acceptOwnership()` must be called by the pending owner (otherwise
   `NotPendingOwner()`); it makes the caller the owner and clears the pending owner.
4. `increment()` may be called by anyone. If `limit` is non-zero and `total` has reached
   it, the call reverts with `LimitReached()`. Otherwise `total` and the caller's
   `perUser` entry increase by one and the new total is returned.
5. `setLimit` is owner only. A limit of zero means "no limit". Setting a limit below the
   current total is allowed and simply blocks further increments.
6. The contract must not read or write any storage slot outside the two namespaces.

## What the Tests Check

- `namespaceSlot` against the formula and against the example value from the ERC.
- The exact slot of every struct member, including mapping entries.
- Operation behind a proxy that keeps its own variables in slots 0 to 2: those slots must
  never change, and the low slots of a directly deployed instance must stay empty.
- The ownership and counter rules, including their revert conditions.
