# Bind Governor and Timelock Execution to the Voted Payload

`PayloadGovernor` lets a fixed set of voters propose a call, vote on it for three days and
queue it in `PayloadTimelock`, which holds the treasury and executes the call after a delay.
To save storage, the proposal payload (`target`, `value`, `data`) is only emitted in an event
and passed again by the caller of `execute`.

## The bug

Queueing records an execution time under the proposal id. Executing looks up that id and then
performs whatever call the caller supplied. Nothing connects the two. `execute` is
permissionless, so once any harmless proposal has passed and its delay has elapsed, anyone
can call `execute(id, attacker, treasuryBalance, "")`.

## Your task

Patch `src/PayloadGovernor.sol`, which contains both contracts. Keep the interfaces unchanged.

```solidity
// PayloadTimelock
constructor(uint256 delay_);
function setGovernor(address governor_) external;                       // deployer, once
function queue(uint256 proposalId, bytes32 payloadHash) external returns (uint256 eta); // governor
function execute(uint256 proposalId, address target, uint256 value, bytes calldata data) external; // governor
function etaOf(uint256 proposalId) external view returns (uint256);

// PayloadGovernor
constructor(address timelock_, address[] memory voters_, uint256 quorum_);
function hashPayload(address target, uint256 value, bytes memory data) external pure returns (bytes32);
function propose(address target, uint256 value, bytes calldata data) external returns (uint256 id);
function castVote(uint256 id, bool support) external;
function queue(uint256 id) external;
function execute(uint256 id, address target, uint256 value, bytes calldata data) external;
function payloadHashOf(uint256 id) external view returns (bytes32);
```

### Required properties

- `hashPayload(target, value, data)` is `keccak256(abi.encode(target, value, data))`.
- `propose` stores that hash; `payloadHashOf(id)` returns it.
- `PayloadGovernor.execute` reverts with `PayloadMismatch()` unless the supplied payload
  hashes to the stored value.
- `PayloadGovernor.queue` passes the stored hash to the timelock. `PayloadTimelock.execute`
  independently reverts with `PayloadMismatch()` unless the supplied payload hashes to the
  value given to `queue` for that proposal id.
- Existing rules stay: voters only (`NotVoter()`), one vote each (`AlreadyVoted()`), voting
  lasts `VOTING_PERIOD` (`VotingClosed()` / `VotingOpen()`), a proposal is queueable when
  `forVotes > againstVotes` and `forVotes >= quorum` (`ProposalDefeated()` otherwise), it is
  queued once (`AlreadyQueued()`), executed once (`AlreadyExecuted()`, `NotQueued()`), and
  not before its eta (`NotReady()`). Timelock entry points are governor-only (`NotGovernor()`).
  A failing target call reverts with `CallFailed()`.

## What the tests check

- After a 1 ETH grant proposal passes, executing with a different recipient, value or
  calldata reverts and the treasury is intact; the voted payload executes exactly once.
- The timelock rejects a mismatching payload even when called by the governor address.
- Voting, queueing, delay and access-control rules.
