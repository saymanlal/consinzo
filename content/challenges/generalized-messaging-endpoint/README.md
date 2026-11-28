# Generalised Messaging Endpoint

## Problem Statement

A generalised message-passing protocol lets a contract on one chain call a contract on
another. On every chain there is one **endpoint** contract. An application calls `send` on
its local endpoint; off-chain infrastructure carries the resulting packet to the
destination chain and calls `deliver` on the endpoint there, which invokes the receiving
application.

Implement `MessagingEndpoint` in `src/MessagingEndpoint.sol`. The same contract plays both
roles. The tests deploy two endpoints with different chain ids and move packets between
them through a trusted `relayer` address.

The endpoint must provide:

- **ordered and unordered channels**, chosen per message by the sender;
- **failed-delivery handling**: a receiver that reverts must not lose the message, and
  must not be able to stall other applications;
- **retry and skip** of failed messages;
- **fees with refund** of overpayment;
- **reentrancy-safe delivery**: the receiver is untrusted code.

## Types

```solidity
interface IMessageReceiver {
    function onMessage(uint256 srcChainId, address sender, uint64 nonce, bool ordered, bytes calldata payload) external;
}

struct Packet {
    uint256 srcChainId;
    address sender;
    uint256 dstChainId;
    address receiver;
    uint64 nonce;
    bool ordered;
    bytes payload;
}

enum Status { None, Delivered, Failed, Skipped }
```

## Interface

```solidity
uint256 public constant GAS_RESERVE = 60_000;

constructor(uint256 localChainId_, address relayer_, uint256 executionGas_)   // owner = msg.sender

// immutable configuration: localChainId, owner, relayer, executionGas

function setFee(uint256 dstChainId, uint120 baseFee, uint120 perByteFee) external;            // owner
function feeConfig(uint256 dstChainId) external view returns (bool enabled, uint120 baseFee, uint120 perByteFee);
function quote(uint256 dstChainId, uint256 payloadLength) external view returns (uint256);
function collectedFees() external view returns (uint256);
function withdrawFees(address to) external returns (uint256 amount);                          // owner

function packetId(Packet memory p) external pure returns (bytes32);
function outboundNonce(address sender, uint256 dstChainId, address receiver, bool ordered) external view returns (uint64);
function send(uint256 dstChainId, address receiver, bytes calldata payload, bool ordered, address refundTo)
    external payable returns (bytes32 id, uint64 nonce);

function status(bytes32 id) external view returns (Status);
function inboundNonce(uint256 srcChainId, address sender, address receiver) external view returns (uint64);
function blockedBy(uint256 srcChainId, address sender, address receiver) external view returns (bytes32);
function deliver(Packet calldata p) external;                                                 // relayer
function retry(Packet calldata p) external;
function skip(Packet calldata p) external;                                                    // p.receiver
```

Errors: `InvalidConfig`, `NotOwner`, `NotRelayer`, `NotReceiver`, `ZeroAddress`,
`UnsupportedChain`, `InsufficientFee`, `RefundFailed`, `WrongChain`, `AlreadyDelivered`,
`OutOfOrder`, `ChannelBlocked`, `NotFailed`, `RetryFailed`, `InsufficientGas`,
`Reentrancy`, `NothingToWithdraw`, `TransferFailed`.

## Rules

### Configuration and fees

1. The constructor reverts with `InvalidConfig()` if the chain id, the relayer or
   `executionGas_` is zero.
2. `setFee` is owner-only (`NotOwner()`), rejects `dstChainId == 0` and
   `dstChainId == localChainId` with `InvalidConfig()`, and enables the destination. Fees
   of zero are allowed.
3. `quote(dstChainId, n) == baseFee + perByteFee * n`; `UnsupportedChain()` if the
   destination was never enabled.
4. `withdrawFees`: `NotOwner()`, then `ZeroAddress()`, then `NothingToWithdraw()`; sends
   exactly `collectedFees` and zeroes it; `TransferFailed()` if the send fails.

### Sending

5. `packetId(p) == keccak256(abi.encode(p.srcChainId, p.sender, p.dstChainId, p.receiver,
   p.nonce, p.ordered, keccak256(p.payload)))`.
6. `send` checks, in order: destination enabled (`UnsupportedChain()`);
   `receiver != address(0)` (`ZeroAddress()`); `msg.value >= quote(...)`
   (`InsufficientFee()`).
7. Nonces are counted separately for every `(sender, dstChainId, receiver, ordered)`
   combination and start at 1. `send` returns the nonce and the id of the packet
   `{localChainId, msg.sender, dstChainId, receiver, nonce, ordered, payload}`.
8. Exactly the quoted fee is added to `collectedFees`. Any excess is sent to `refundTo`,
   or to `msg.sender` when `refundTo` is the zero address. If that transfer fails, `send`
   reverts with `RefundFailed()`.
9. `send` may be called at any time, including from inside `onMessage` (a reply) and from
   inside a refund callback. A nested `send` must get its own nonce and must not disturb
   the fee accounting of the outer one.

### Delivering

10. `deliver` checks, in order: caller is the relayer (`NotRelayer()`);
    `p.dstChainId == localChainId` (`WrongChain()`); `status[packetId(p)] == None`
    (`AlreadyDelivered()`).
11. For an **ordered** packet it then checks, in order: the channel
    `(srcChainId, sender, receiver)` is not blocked (`ChannelBlocked()`); `p.nonce` equals
    `inboundNonce + 1` (`OutOfOrder()`). On passing, `inboundNonce` becomes `p.nonce`.
    **Unordered** packets may arrive in any order and never touch `inboundNonce` or
    `blockedBy`.
12. The endpoint then calls
    `IMessageReceiver(p.receiver).onMessage(p.srcChainId, p.sender, p.nonce, p.ordered, p.payload)`
    with a gas limit of exactly `executionGas`.
    - Success: status `Delivered`.
    - Failure (revert, out of gas, or `p.receiver` has no code): status `Failed`; `deliver`
      itself does **not** revert. For an ordered packet the nonce stays consumed and
      `blockedBy[srcChainId][sender][receiver]` is set to the packet id.
13. A blocked ordered channel accepts no further packets until the blocking message is
    retried successfully or skipped. Other channels are unaffected, including the unordered
    traffic between the same two applications.

### Gas

14. Before calling the receiver, `deliver` and `retry` revert with `InsufficientGas()` if
    `gasleft() < executionGas * 64 / 63 + GAS_RESERVE`. A caller that supplies too little
    gas must not be able to turn a healthy message into a `Failed` one.

### Retry and skip

15. `retry(p)` can be called by anyone. `NotFailed()` unless the status is `Failed`. It
    runs the receiver again under rules 12 and 14. Success: status `Delivered` and, for an
    ordered packet, the channel is unblocked. Failure: revert with `RetryFailed()`, leaving
    everything as it was.
16. `skip(p)` can be called only by `p.receiver` (`NotReceiver()`, checked first), and only
    for a `Failed` message (`NotFailed()`). Status becomes `Skipped`; an ordered channel is
    unblocked. A skipped message can never be delivered or retried.

### Reentrancy

17. `deliver`, `retry` and `skip` share one lock. Entering any of them while one is running
    reverts with `Reentrancy()`. `send` is not covered by the lock (rule 9).
18. Whatever a receiver does during `onMessage`, each message is executed successfully at
    most once.

## What the tests check

End-to-end messaging between two endpoints including a reply sent from `onMessage`;
ordering, blocking, retry and skip on ordered channels; independence of channels; replay
and tampering; receivers that revert, run out of gas, have no code or re-enter; gas
starvation by the caller; fee quoting, refunds to well-behaved, rejecting and re-entering
refund targets; and fee withdrawal.
