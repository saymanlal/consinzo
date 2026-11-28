// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract TwoStepOwnable {
    error NotOwner(address caller);
    error NotPendingOwner(address caller);
    error ZeroAddress();
    error NoPendingOwner();

    event OwnershipProposed(address indexed currentOwner, address indexed proposedOwner);
    event ProposalCancelled(address indexed cancelledOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address public owner;
    address public pendingOwner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function proposeOwner(address candidate) external onlyOwner {
        if (candidate == address(0)) revert ZeroAddress();
        // A new proposal replaces the previous one; only one candidate can be pending.
        pendingOwner = candidate;
        emit OwnershipProposed(msg.sender, candidate);
    }

    function cancelProposal() external onlyOwner {
        address candidate = pendingOwner;
        if (candidate == address(0)) revert NoPendingOwner();
        delete pendingOwner;
        emit ProposalCancelled(candidate);
    }

    function acceptOwnership() external {
        // msg.sender is never address(0), so this also rejects the "nothing pending" case.
        if (msg.sender != pendingOwner) revert NotPendingOwner(msg.sender);

        address previousOwner = owner;
        owner = msg.sender;
        // Clearing the slot prevents the same acceptance from being replayed later.
        delete pendingOwner;

        emit OwnershipTransferred(previousOwner, msg.sender);
    }
}
