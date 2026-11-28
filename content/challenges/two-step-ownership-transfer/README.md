# Two-Step Ownership Transfer

## Problem Statement

Implement `TwoStepOwnable` in `src/TwoStepOwnable.sol`. A one-step `transferOwnership(newOwner)`
loses the contract for good if `newOwner` is mistyped. Here the transfer takes two steps: the owner
proposes a candidate and the candidate accepts from that address, which proves the address is
controlled by someone.

## Required Interface

```solidity
error NotOwner(address caller);
error NotPendingOwner(address caller);
error ZeroAddress();
error NoPendingOwner();

event OwnershipProposed(address indexed currentOwner, address indexed proposedOwner);
event ProposalCancelled(address indexed cancelledOwner);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

function owner() external view returns (address);
function pendingOwner() external view returns (address);
function proposeOwner(address candidate) external;
function cancelProposal() external;
function acceptOwnership() external;
```

## Rules

1. The deployer is the first owner. The constructor emits
   `OwnershipTransferred(address(0), deployer)`. `pendingOwner` starts as `address(0)`.
2. `proposeOwner(candidate)`:
   - reverts with `NotOwner(msg.sender)` unless called by the owner;
   - reverts with `ZeroAddress()` if `candidate == address(0)`;
   - sets `pendingOwner = candidate`, replacing any earlier proposal, and emits
     `OwnershipProposed(owner, candidate)`.
   - `owner` is unchanged.
3. `cancelProposal()`:
   - reverts with `NotOwner(msg.sender)` unless called by the owner;
   - reverts with `NoPendingOwner()` if there is no pending proposal;
   - clears `pendingOwner` and emits `ProposalCancelled(cancelledCandidate)`.
4. `acceptOwnership()`:
   - reverts with `NotPendingOwner(msg.sender)` unless called by the current `pendingOwner`
     (this includes the case where nothing is pending);
   - sets `owner = msg.sender`, clears `pendingOwner` and emits
     `OwnershipTransferred(previousOwner, newOwner)`.
5. In every function the caller check comes before the other checks.

## What the Tests Check

- Proposing does not move ownership; accepting does.
- Only the pending owner can accept; the previous owner loses all rights after acceptance.
- Replacing and cancelling proposals invalidates the earlier candidate.
- All revert conditions with their arguments.
