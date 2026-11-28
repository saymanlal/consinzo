// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title SealedBidAuction
/// @notice Two-phase (commit, reveal) ETH auction. Highest revealed bid wins.
contract SealedBidAuction {
    error WrongPhase();
    error ZeroDeposit();
    error AlreadyCommitted();
    error AlreadyRevealed();
    error InvalidReveal();
    error BidExceedsDeposit();
    error NothingToWithdraw();
    error NotSeller();
    error TransferFailed();

    address public immutable seller;
    uint256 public immutable commitEnd;
    uint256 public immutable revealEnd;

    mapping(address => bytes32) public commitments;
    mapping(address => uint256) public deposits;
    mapping(address => bool) public revealed;

    address public highestBidder;
    uint256 public highestBid;
    bool public proceedsClaimed;

    constructor(uint256 commitDuration, uint256 revealDuration) {
        seller = msg.sender;
        commitEnd = block.timestamp + commitDuration;
        revealEnd = commitEnd + revealDuration;
    }

    function computeCommitment(address bidder, uint256 amount, bytes32 salt) public view returns (bytes32) {
        // TODO: the commitment does not depend on `bidder` (or on this auction).
        bidder;
        return keccak256(abi.encode(amount, salt));
    }

    function commit(bytes32 commitment) external payable {
        if (block.timestamp >= commitEnd) revert WrongPhase();
        if (msg.value == 0) revert ZeroDeposit();
        if (commitments[msg.sender] != bytes32(0)) revert AlreadyCommitted();
        commitments[msg.sender] = commitment;
        deposits[msg.sender] = msg.value;
    }

    function reveal(uint256 amount, bytes32 salt) external {
        if (block.timestamp < commitEnd || block.timestamp >= revealEnd) revert WrongPhase();
        if (revealed[msg.sender]) revert AlreadyRevealed();
        bytes32 stored = commitments[msg.sender];
        if (stored == bytes32(0) || stored != computeCommitment(msg.sender, amount, salt)) revert InvalidReveal();
        if (amount > deposits[msg.sender]) revert BidExceedsDeposit();

        revealed[msg.sender] = true;
        // Strictly greater: ties go to the earlier reveal.
        if (amount > highestBid) {
            highestBid = amount;
            highestBidder = msg.sender;
        }
    }

    function withdraw() external {
        if (block.timestamp < revealEnd) revert WrongPhase();
        uint256 deposit = deposits[msg.sender];
        uint256 amount = deposit;
        // The winner's bid stays locked for the seller; only the excess deposit is refundable.
        if (msg.sender == highestBidder) amount -= highestBid;
        if (amount == 0) revert NothingToWithdraw();
        deposits[msg.sender] = deposit - amount;
        _send(msg.sender, amount);
    }

    function claimProceeds() external {
        if (msg.sender != seller) revert NotSeller();
        if (block.timestamp < revealEnd) revert WrongPhase();
        if (proceedsClaimed || highestBid == 0) revert NothingToWithdraw();
        proceedsClaimed = true;
        _send(seller, highestBid);
    }

    function _send(address to, uint256 amount) private {
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
