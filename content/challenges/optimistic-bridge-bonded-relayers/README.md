# Optimistic Bridge with Bonded Relayers

## Problem Statement

An optimistic bridge does not verify a cross-chain message when it arrives. A relayer
*asserts* that the message was sent on the source chain and puts money behind the
assertion. For a fixed period anyone can dispute it. If nobody does, the message is
executed. If someone does and the assertion was false, the relayer's bond is slashed and
handed to the challenger.

Implement `OptimisticBridge` in `src/OptimisticBridge.sol`: the destination side of such a
bridge, paying out ETH. The source chain is not simulated. The outcome of a dispute is
supplied by an `arbiter` address, which stands in for a fraud-proof verifier.

The contract holds three kinds of ETH and must never mix them up:

- **liquidity** – deposited through `receive()`, used to pay finalized messages;
- **bonds** – posted by relayers and challengers, locked in claims;
- **credits** – amounts already owed to someone, collected with `withdraw()`.

## Interface

```solidity
enum Status { None, Pending, Challenged, Upheld, Finalized }

struct Claim {
    address relayer;
    address recipient;
    uint256 amount;
    uint256 bond;
    uint256 postedAt;
    address challenger;
    Status status;
}

constructor(address arbiter_, uint256 bondAmount_, uint256 challengePeriod_)   // owner = msg.sender
receive() external payable;

function owner() external view returns (address);
function arbiter() external view returns (address);
function challengePeriod() external view returns (uint256);
function bondAmount() external view returns (uint256);
function liquidity() external view returns (uint256);
function credits(address account) external view returns (uint256);

function setBondAmount(uint256 bondAmount_) external;                           // owner
function slotOf(uint256 srcChainId, uint256 nonce) external pure returns (bytes32);
function getClaim(bytes32 slot) external view returns (Claim memory);

function postMessage(uint256 srcChainId, uint256 nonce, address recipient, uint256 amount)
    external payable returns (bytes32 slot);
function challenge(bytes32 slot) external payable;
function resolve(bytes32 slot, bool fraudulent) external;                       // arbiter
function finalize(bytes32 slot) external;
function withdraw() external returns (uint256 amount);
```

Errors: `NotOwner`, `NotArbiter`, `InvalidConfig`, `InvalidMessage`, `BadBond`, `SlotTaken`,
`NotPending`, `NotChallenged`, `ChallengeWindowClosed`, `ChallengeWindowOpen`,
`InsufficientLiquidity`, `NothingToWithdraw`, `TransferFailed`.

## Rules

1. The constructor reverts with `InvalidConfig()` if the arbiter is the zero address or the
   bond or the challenge period is zero.
2. `receive()` adds `msg.value` to `liquidity`.
3. `setBondAmount` is owner-only (`NotOwner()`), rejects zero (`InvalidConfig()`), and only
   affects claims posted afterwards.
4. `slotOf(srcChainId, nonce) == keccak256(abi.encode(srcChainId, nonce))`. A source
   message has exactly one slot regardless of what a relayer claims about its content.

### Posting

5. `postMessage` checks, in order: `recipient != address(0)` and `amount != 0`
   (`InvalidMessage()`); `msg.value == bondAmount` (`BadBond()`); the slot's status is
   `None` (`SlotTaken()`).
6. It stores a `Pending` claim with `relayer = msg.sender`, `bond = msg.value`,
   `postedAt = block.timestamp`, and returns the slot.

### Challenging

7. `challenge` checks, in order: the claim is `Pending` (`NotPending()`);
   `block.timestamp < postedAt + challengePeriod` (`ChallengeWindowClosed()`);
   `msg.value == claim.bond` (`BadBond()`). The required value is the bond stored in the
   claim, even if `bondAmount` has changed since. It records the challenger and sets the
   status to `Challenged`. A claim can be challenged once.

### Resolving

8. `resolve` is arbiter-only (`NotArbiter()`), and the claim must be `Challenged`
   (`NotChallenged()`).
9. `fraudulent == true`: the challenger is credited `2 * bond` (their own bond plus the
   slashed one) and the claim is deleted, so the slot's status is `None` again and a new
   claim can be posted for it.
10. `fraudulent == false`: the relayer is credited `bond` (the challenger's bond) and the
    status becomes `Upheld`. The relayer's own bond stays locked until finalization. An
    upheld claim cannot be challenged again.

### Finalizing

11. `finalize` can be called by anyone. A `Pending` claim finalizes once
    `block.timestamp >= postedAt + challengePeriod` (earlier: `ChallengeWindowOpen()`). An
    `Upheld` claim finalizes immediately. Any other status reverts with `NotPending()`; in
    particular a `Challenged` claim cannot be finalized no matter how much time has passed.
12. If `amount > liquidity` it reverts with `InsufficientLiquidity()` and the claim stays as
    it was, to be finalized later. Bonds and credits held by the contract do not count.
13. Otherwise the status becomes `Finalized`, `liquidity` drops by `amount`, the recipient
    is credited `amount` and the relayer is credited their bond. A finalized slot can never
    be used again.

### Withdrawing

14. `withdraw` sends the caller their whole credit and returns the amount. It reverts with
    `NothingToWithdraw()` when the credit is zero and `TransferFailed()` when the ETH
    transfer fails. A recipient that re-enters must not be able to receive more than its
    credit.

**Invariant.** `address(this).balance == liquidity + sum of bonds locked in live claims +
sum of credits`.

## What the tests check

The full life cycle in both dispute outcomes, exact window boundaries, exact slashing
amounts, slot reuse after a rejected claim, bond changes while claims are live, payout
limits when liquidity is short but bonds are present, reentrancy on `withdraw`, access
control, and the balance invariant after mixed sequences.
