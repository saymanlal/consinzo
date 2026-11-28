# Bind Sealed-Bid Commitments to the Bidder

`SealedBidAuction` is a two-phase ETH auction. During the commit phase a bidder stores a hash
and locks a deposit. During the reveal phase the bidder discloses `amount` and `salt`; the
highest revealed amount wins and ties go to whoever revealed first.

## The bug

The commitment is `keccak256(abi.encode(amount, salt))`. Nothing in it identifies the bidder.
An attacker copies an honest bidder's commitment during the commit phase, waits for the
honest reveal transaction to appear, and front-runs it with the same `amount` and `salt`.
The attacker's reveal is accepted, the attacker becomes the highest bidder, and the honest
bidder's identical bid loses the tie.

## Your task

Patch `src/SealedBidAuction.sol` so that a commitment can only be opened by the account that
made it, in the auction it was made for. Keep the external interface unchanged.

### Required interface

```solidity
constructor(uint256 commitDuration, uint256 revealDuration); // deployer is the seller
function computeCommitment(address bidder, uint256 amount, bytes32 salt) external view returns (bytes32);
function commit(bytes32 commitment) external payable;
function reveal(uint256 amount, bytes32 salt) external;
function withdraw() external;
function claimProceeds() external;
```

### Rules

- `computeCommitment` must return
  `keccak256(abi.encode(address(this), bidder, amount, salt))`.
- `reveal` checks the caller's stored commitment against `computeCommitment(msg.sender, amount, salt)`
  and reverts with `InvalidReveal()` on a mismatch.
- `commit`: commit phase only (`WrongPhase()`), non-zero deposit (`ZeroDeposit()`), one
  commitment per bidder (`AlreadyCommitted()`).
- `reveal`: reveal phase only (`WrongPhase()`), once per bidder (`AlreadyRevealed()`),
  `amount` may not exceed the caller's deposit (`BidExceedsDeposit()`). A strictly higher
  amount replaces the current highest bid.
- `withdraw`: after the reveal phase. The winner receives `deposit - highestBid`; everyone
  else, including bidders who never revealed, receives their full deposit. A second call, or
  a call with nothing to collect, reverts with `NothingToWithdraw()`.
- `claimProceeds`: seller only (`NotSeller()`), after the reveal phase, pays `highestBid` once.

Phases are defined by `commitEnd` and `revealEnd`: commit while `block.timestamp < commitEnd`,
reveal while `commitEnd <= block.timestamp < revealEnd`.

## What the tests check

- A copied commitment cannot be revealed by the copier, and the honest bidder still wins.
- Commitments differ per bidder and per auction instance and match the formula above.
- Phase, deposit and double-action rules, and the exact refund and proceeds amounts.
