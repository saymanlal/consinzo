# Checkpoint Bridge with Validator-Set Rotation

## Problem Statement

A checkpoint bridge does not relay messages one by one. Periodically the other chain's
pending withdrawals are committed into a Merkle tree, and a validator set attests to the
root. Once enough validators agree, the root is accepted on this chain and every user can
exit by proving that their withdrawal is a leaf of the tree. The validator set itself
changes over time, and the hand-over is the most delicate part of such a bridge.

Implement `CheckpointBridge` in `src/CheckpointBridge.sol`. It pays withdrawals in ETH from
its own balance (funded through `receive()`).

Attestations are **address based**: a validator attests by calling the contract from its
own address. There are no signatures to verify.

## Interface

```solidity
uint256 public constant MAX_VALIDATORS = 32;

constructor(address[] memory validators_)
receive() external payable;

function epoch() external view returns (uint256);
function validatorCount() external view returns (uint256);
function isValidator(address account) external view returns (bool);
function quorum() external view returns (uint256);

function rotationHash(uint256 newEpoch, address[] memory newValidators) external pure returns (bytes32);
function rotationVotes(bytes32 proposal) external view returns (uint256);
function attestRotation(address[] calldata newValidators) external;

function checkpointRoot(uint256 checkpointId) external view returns (bytes32);
function checkpointVotes(uint256 checkpointId, bytes32 root) external view returns (uint256);
function attestCheckpoint(uint256 checkpointId, bytes32 root) external;

function leafOf(uint256 nonce, address recipient, uint256 amount) external pure returns (bytes32);
function verifyProof(bytes32 root, bytes32 leaf, uint256 index, bytes32[] calldata proof) external pure returns (bool);
function withdrawn(uint256 nonce) external view returns (bool);
function withdraw(uint256 checkpointId, uint256 index, uint256 nonce, address recipient, uint256 amount, bytes32[] calldata proof) external;
```

Errors: `InvalidValidatorSet`, `NotValidator`, `InvalidRoot`, `CheckpointFinal`,
`AlreadyAttested`, `UnknownCheckpoint`, `AlreadyWithdrawn`, `InvalidProof`,
`TransferFailed`.

## Rules

### Validator sets and epochs

1. A valid set has between 1 and `MAX_VALIDATORS` addresses in **strictly ascending**
   order. That rules out duplicates and the zero address. Anything else is
   `InvalidValidatorSet()`.
2. The constructor installs the first set as epoch `1`. Every rotation increases `epoch`
   by one. `isValidator` and `validatorCount` always describe the current epoch's set.
3. `quorum()` is the smallest number of validators strictly greater than two thirds of the
   set: `validatorCount * 2 / 3 + 1`.

### Rotation

4. `rotationHash(newEpoch, newValidators) == keccak256(abi.encode(newEpoch, newValidators))`.
   A proposal made during epoch `e` is identified by `rotationHash(e + 1, newValidators)`.
5. `attestRotation(newValidators)` checks, in order: caller is a current validator
   (`NotValidator()`); the set is valid (`InvalidValidatorSet()`); the caller has not
   already attested to this proposal in this epoch (`AlreadyAttested()`). A validator may
   attest to several different proposals.
6. When a proposal reaches `quorum()` in the call that adds the deciding vote, the new set
   is installed immediately and `epoch` increases.
7. `rotationVotes(proposal)` and `checkpointVotes(id, root)` report tallies **of the
   current epoch**. All attestations, for rotations and for checkpoints, belong to the
   epoch in which they were made. After a rotation every tally starts from zero: votes of
   the previous set do not count, including the votes of validators who are also members
   of the new set. Those validators may attest again in the new epoch.

### Checkpoints

8. `attestCheckpoint(checkpointId, root)` checks, in order: caller is a current validator
   (`NotValidator()`); `root != 0` (`InvalidRoot()`); the checkpoint has no accepted root
   yet (`CheckpointFinal()`); the caller has not attested to this checkpoint id in this
   epoch (`AlreadyAttested()`).
9. A validator has one vote per checkpoint id per epoch. Having voted for one root it
   cannot vote for another root of the same checkpoint.
10. When a root reaches `quorum()` votes it is stored in `checkpointRoot[checkpointId]` and
    is final. Votes for different roots are never added together.

### Merkle tree

11. Leaf: `keccak256(bytes.concat(keccak256(abi.encode(nonce, recipient, amount))))`.
12. Inner node: `keccak256(abi.encode(left, right))`. The tree is positional, not sorted.
13. `verifyProof` starts from `leaf` at position `index` of the bottom level. For each
    proof element, from the bottom up: if the lowest bit of the index is `1` the node is a
    right child (`hash(proofElement, node)`), otherwise a left child
    (`hash(node, proofElement)`); then the index is shifted right by one. The proof is
    valid only if the final node equals `root` **and** the remaining index is `0`.
    A single-leaf tree has `root == leaf`, `index == 0` and an empty proof.

### Withdrawals

14. `withdraw` can be called by anyone on behalf of the recipient. It checks, in order: the
    checkpoint has an accepted root (`UnknownCheckpoint()`); `nonce` has not been paid
    (`AlreadyWithdrawn()`); the proof is valid for
    `leafOf(nonce, recipient, amount)` at `index` (`InvalidProof()`).
15. It then marks the nonce as withdrawn and sends `amount` wei to `recipient`. A failed
    send reverts with `TransferFailed()` and leaves the nonce unpaid.
16. A withdrawal nonce is paid at most once in the lifetime of the contract, even if the
    same leaf is included in more than one accepted checkpoint, and even if the recipient
    re-enters during the payment.

## What the tests check

Quorum arithmetic for several set sizes, equivocation and split votes, finality of
accepted roots, set validation, rotation including stale votes and removed validators,
positional proof verification with wrong index, wrong data and wrong proof length, replay
within and across checkpoints, reentrancy and failed payments.
