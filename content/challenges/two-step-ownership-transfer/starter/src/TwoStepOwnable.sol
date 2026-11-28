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

    constructor() {
        // TODO: the deployer becomes the owner; emit OwnershipTransferred(address(0), deployer)
    }

    function proposeOwner(address candidate) external {
        // TODO: owner only; reject address(0); record the candidate; emit OwnershipProposed
        revert("NOT_IMPLEMENTED");
    }

    function cancelProposal() external {
        // TODO: owner only; revert if nothing is pending; clear it; emit ProposalCancelled
        revert("NOT_IMPLEMENTED");
    }

    function acceptOwnership() external {
        // TODO: pending owner only; move ownership; clear pendingOwner; emit OwnershipTransferred
        revert("NOT_IMPLEMENTED");
    }
}
