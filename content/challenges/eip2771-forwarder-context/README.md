# EIP-2771 Recipient: Recover the Original Sender from Calldata

## Problem Statement

With meta-transactions a user signs a request and a relayer pays the gas. A *trusted
forwarder* contract verifies the signature and then calls the target contract, appending
the user's address (20 bytes) to the calldata. The target (the *recipient*) must use that
appended address instead of `msg.sender`, but only when the call really comes from the
forwarder it trusts.

Implement `MetaTxRecipient` in `src/MetaTxRecipient.sol`. It is a small vault with notes
and an owner, in which every notion of "the caller" follows EIP-2771.

## Required Interface

```solidity
error ZeroAddress();
error NotOwner();
error InsufficientBalance();
error TransferFailed();

event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
event Deposited(address indexed account, uint256 amount);
event Withdrawn(address indexed account, uint256 amount);
event NoteSet(address indexed account, string note);

constructor(address forwarder);

function trustedForwarder() external view returns (address);
function isTrustedForwarder(address forwarder) external view returns (bool);
function owner() external view returns (address);
function balanceOf(address account) external view returns (uint256);
function noteOf(address account) external view returns (string memory);

function context() external view returns (address sender, bytes memory data);
function transferOwnership(address newOwner) external;
function deposit() external payable;
function withdraw(uint256 amount) external;
function setNote(string calldata note) external;
```

## Rules

1. The constructor stores the forwarder (it cannot be changed) and reverts with
   `ZeroAddress()` if it is the zero address. The initial owner is the deployer
   (`msg.sender` of the constructor).
2. The **effective sender** of a call is:
   - the address in the last 20 bytes of calldata, if `msg.sender` is the trusted forwarder
     **and** the calldata is at least 20 bytes long;
   - `msg.sender` otherwise.
3. The **effective calldata** is `msg.data` without those last 20 bytes in the first case
   and the unmodified `msg.data` otherwise.
4. `context()` returns the effective sender and effective calldata of the call to
   `context()` itself.
5. `transferOwnership` may only be called by the owner as effective sender (`NotOwner()`
   otherwise) and rejects the zero address with `ZeroAddress()`.
6. `deposit` credits `msg.value` to the effective sender. `withdraw` debits the effective
   sender, reverts with `InsufficientBalance()` if the balance is too low, and sends the
   ether to the effective sender (`TransferFailed()` if the send fails).
7. `setNote` stores the note for the effective sender.
8. A caller that is not the trusted forwarder gains nothing by appending an address to
   its calldata.

## What the Tests Check

- Direct calls and calls relayed through a forwarder for every function.
- That appended addresses from untrusted callers are ignored.
- Short calldata from the forwarder, the effective calldata, and where withdrawn ether goes.
