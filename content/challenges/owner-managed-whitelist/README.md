# Owner-Managed Address Whitelist

## Problem Statement

Implement `Whitelist` in `src/Whitelist.sol`. The deployer owns the list and decides which
addresses are on it. Listed addresses can call `checkIn()`; everyone else is rejected.

## Required Interface

```solidity
error NotOwner(address caller);
error ZeroAddress();
error NotAllowed(address caller);

event Added(address indexed account);
event Removed(address indexed account);
event CheckedIn(address indexed account, uint256 count);

function owner() external view returns (address);
function allowedCount() external view returns (uint256);
function isAllowed(address account) external view returns (bool);
function checkIns(address account) external view returns (uint256);

function add(address account) external returns (bool changed);
function remove(address account) external returns (bool changed);
function addBatch(address[] calldata accounts) external returns (uint256 added);
function removeBatch(address[] calldata accounts) external returns (uint256 removed);
function checkIn() external;
```

## Rules

1. The deployer is the owner. `add`, `remove`, `addBatch` and `removeBatch` revert with
   `NotOwner(msg.sender)` for any other caller. This check comes first.
2. `add(account)`:
   - reverts with `ZeroAddress()` if `account == address(0)`;
   - if the account is not listed: lists it, increases `allowedCount`, emits `Added(account)` and
     returns `true`;
   - if it is already listed: changes nothing, emits nothing and returns `false`.
3. `remove(account)`:
   - if the account is listed: unlists it, decreases `allowedCount`, emits `Removed(account)` and
     returns `true`;
   - otherwise changes nothing and returns `false` (this includes `address(0)`).
4. `addBatch(accounts)` applies the `add` rule to each element in order and returns how many
   addresses were newly listed. If any element is `address(0)` the whole call reverts with
   `ZeroAddress()` and nothing is added. Duplicates inside the batch are listed once.
5. `removeBatch(accounts)` applies the `remove` rule to each element and returns how many addresses
   were actually removed.
6. An empty batch is valid and returns `0`.
7. `checkIn()` reverts with `NotAllowed(msg.sender)` unless the caller is currently listed.
   Otherwise it increases `checkIns[msg.sender]` by one and emits
   `CheckedIn(msg.sender, newCount)`. The owner is not listed automatically.
8. Removing an address does not erase its `checkIns` history.

## What the Tests Check

- Single and batch adds/removes with the returned values and `allowedCount`.
- Repeated adds/removes and duplicates in a batch do not distort the count.
- A batch containing the zero address is rejected as a whole.
- `checkIn` works only for listed addresses and stops working after removal.
- Only the owner can manage the list.
