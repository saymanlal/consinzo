# Cross-Chain Governance Receiver

## Problem Statement

A DAO votes on its home chain, but it also owns contracts on other chains. Those contracts
are administered by a *receiver*: a contract that accepts proposals relayed from the home
governor through a messaging bridge, holds them in a timelock and then lets anyone execute
them.

Implement `GovernanceReceiver` in `src/GovernanceReceiver.sol`.

The bridge is modelled by a messenger mock that calls
`receiveMessage(sourceChainId, sourceSender, payload)` on the receiver. The messenger is
trusted to report the origin honestly; the receiver decides which origin it trusts. To keep
storage small the receiver stores only a hash of each proposal's actions; the executor
supplies the actions again and the receiver verifies them against the hash.

## Interface

```solidity
enum State { None, Queued, Executed, Cancelled, Expired }

uint256 public constant MIN_DELAY = 1 hours;
uint256 public constant MAX_DELAY = 30 days;
uint256 public constant GRACE_PERIOD = 7 days;

constructor(address messenger_, uint256 remoteChainId_, address remoteGovernor_, address guardian_, uint256 delay_)

function messenger() external view returns (address);
function remoteChainId() external view returns (uint256);
function remoteGovernor() external view returns (address);
function guardian() external view returns (address);
function delay() external view returns (uint256);

function receiveMessage(uint256 sourceChainId, address sourceSender, bytes calldata payload) external;
function execute(uint256 proposalId, address[] calldata targets, uint256[] calldata values, bytes[] calldata calldatas) external;
function cancel(uint256 proposalId) external;

function setDelay(uint256 newDelay) external;
function setRemoteGovernor(address newGovernor) external;
function setGuardian(address newGuardian) external;

function state(uint256 proposalId) external view returns (State);
function etaOf(uint256 proposalId) external view returns (uint256);
function actionsHashOf(uint256 proposalId) external view returns (bytes32);
function hashActions(address[] calldata targets, uint256[] calldata values, bytes[] calldata calldatas) external pure returns (bytes32);

receive() external payable;

event ProposalQueued(uint256 indexed proposalId, bytes32 actionsHash, uint256 eta);
event ProposalExecuted(uint256 indexed proposalId);
event ProposalCancelled(uint256 indexed proposalId);
event DelayUpdated(uint256 newDelay);
event RemoteGovernorUpdated(address newGovernor);
event GuardianUpdated(address newGuardian);

error ZeroAddress();
error InvalidDelay();
error NotMessenger();
error UntrustedSource();
error InvalidProposal();
error ProposalExists();
error NotQueued();
error TimelockNotElapsed();
error ProposalExpired();
error ActionsMismatch();
error CallFailed(uint256 index);
error NotGuardian();
error OnlySelf();
```

## Rules

### Construction

1. Reverts with `ZeroAddress()` if `messenger_` or `remoteGovernor_` is zero, and with
   `InvalidDelay()` unless `MIN_DELAY <= delay_ <= MAX_DELAY`. `guardian_` may be zero (no
   guardian).

### Receiving

2. `receiveMessage` checks, in this order:
   - `msg.sender == messenger`, else `NotMessenger()`;
   - `sourceChainId == remoteChainId` **and** `sourceSender == remoteGovernor`, else
     `UntrustedSource()`;
   - the payload, which is
     `abi.encode(uint256 proposalId, address[] targets, uint256[] values, bytes[] calldatas)`,
     has at least one action and all three arrays have the same length, else
     `InvalidProposal()`;
   - no proposal with this id was ever queued (whatever happened to it since), else
     `ProposalExists()`.
3. It stores `actionsHash = keccak256(abi.encode(targets, values, calldatas))` and
   `eta = block.timestamp + delay`, and emits `ProposalQueued`. `hashActions` returns the
   same hash for the same arrays.

### Executing

4. `execute` may be called by anyone. Checks, in this order:
   - the proposal is stored as queued (not unknown, executed or cancelled), else `NotQueued()`;
   - `block.timestamp >= eta`, else `TimelockNotElapsed()`;
   - `block.timestamp <= eta + GRACE_PERIOD`, else `ProposalExpired()`;
   - the supplied arrays hash to the stored `actionsHash`, else `ActionsMismatch()`.
5. The proposal is marked executed **before** any call is made. The actions are then
   performed in order as `targets[i].call{value: values[i]}(calldatas[i])`, paid from the
   receiver's own balance. If action `i` fails the whole transaction reverts with
   `CallFailed(i)`, so a proposal is executed completely or not at all and stays queued
   after a failed attempt. Emits `ProposalExecuted`.

### Cancelling

6. `cancel` can be called only by the guardian (`NotGuardian()`, checked first) for a
   proposal that is stored as queued, including one whose grace period has passed
   (`NotQueued()` otherwise). A cancelled proposal can never be executed and its id cannot
   be reused.

### Self-administration

7. `setDelay`, `setRemoteGovernor` and `setGuardian` revert with `OnlySelf()` unless
   `msg.sender == address(this)`: they can be reached only through an executed proposal.
   `setDelay` enforces the same bounds as the constructor (`InvalidDelay()`);
   `setRemoteGovernor` rejects zero (`ZeroAddress()`); `setGuardian` accepts zero. Changing
   the delay does not change the `eta` of proposals already queued.

### Views

8. `state(id)` returns `None` for unknown ids, `Executed` / `Cancelled` for finished ones,
   `Expired` for a queued proposal with `block.timestamp > eta + GRACE_PERIOD`, otherwise
   `Queued`. `etaOf` and `actionsHashOf` return zero for unknown ids.

## What the tests check

- Origin filtering by messenger, chain id and sender.
- Timelock and grace-period boundaries, hash verification, atomic execution, ETH-carrying
  actions.
- Re-entrant execution attempts from a target, replay of proposal ids, guardian powers and
  the self-administration path, including governor rotation.
