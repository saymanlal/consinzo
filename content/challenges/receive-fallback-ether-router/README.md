# Ether Router with receive and fallback

## Problem Statement

Implement `EtherRouter` in `src/EtherRouter.sol`. The contract accepts Ether in two ways and keeps
them apart:

- a **plain transfer**: a call with empty calldata;
- an **unknown call**: a call whose calldata is not empty and does not match any function of the
  contract.

## Required Interface

```solidity
uint256 public receiveCount;          // number of plain transfers
uint256 public fallbackCount;         // number of unknown calls
uint256 public totalViaReceive;       // wei received through plain transfers
uint256 public totalViaFallback;      // wei received through unknown calls
bytes4  public lastUnknownSelector;   // msg.sig of the most recent unknown call
mapping(address => uint256) public contributionOf;   // wei sent by each address, both paths

event Received(address indexed from, uint256 amount);
event UnknownCall(address indexed from, bytes4 selector, uint256 amount);

receive() external payable;
fallback() external payable;

function ping() external pure returns (bytes4);
function balance() external view returns (uint256);
```

## Rules

1. A call with empty calldata is a plain transfer, whether or not it carries value. It increments
   `receiveCount`, adds `msg.value` to `totalViaReceive` and to `contributionOf[msg.sender]`, and
   emits `Received(msg.sender, msg.value)`.
2. A call with non-empty calldata that matches no function is an unknown call, whether or not it
   carries value. It must succeed. It increments `fallbackCount`, adds `msg.value` to
   `totalViaFallback` and to `contributionOf[msg.sender]`, stores `msg.sig` in
   `lastUnknownSelector`, and emits `UnknownCall(msg.sender, msg.sig, msg.value)`.
3. Calldata shorter than four bytes is still an unknown call. The stored selector is the calldata
   padded on the right with zero bytes, which is what `msg.sig` returns.
4. `ping()` returns its own selector, `EtherRouter.ping.selector`. Calling it, or any other
   declared function, changes no counter.
5. `balance()` returns the contract's Ether balance.

The state variables and events are declared in the starter. Add the two special functions and
fill in the bodies.

## What the Tests Check

- Plain transfers and unknown calls are counted and totalled separately.
- Zero-value calls on both paths, short calldata, and the recorded selector.
- Per-sender contributions across both paths.
- Declared functions do not disturb the counters.
