# Linear Payment Streams with Pro-Rata Cancellation

## Problem Statement

Implement `PaymentStreams` in `src/PaymentStreams.sol`. A sender escrows `deposit` tokens for a
recipient. The tokens become available to the recipient linearly between `startTime` and
`stopTime`. The recipient may withdraw any part of what has accrued. The sender or the recipient
may cancel the stream at any time; the accrued part goes to the recipient and the remainder is
refunded to the sender.

## Interface

```solidity
function createStream(address recipient, address token, uint256 deposit, uint256 startTime, uint256 stopTime)
    external returns (uint256 streamId)
function streamedAmount(uint256 streamId) public view returns (uint256)
function withdrawable(uint256 streamId) public view returns (uint256)
function withdraw(uint256 streamId, uint256 amount) external
function cancel(uint256 streamId) external returns (uint256 recipientAmount, uint256 senderAmount)
```

Public state declared in the starter: `nextStreamId` and
`streams(uint256) returns (sender, recipient, token, deposit, startTime, stopTime, withdrawn, active)`.

## Rules

1. `createStream`, checks in this order:
   - `InvalidRecipient()` if `recipient` is `address(0)`, the contract itself or the caller;
   - `ZeroAmount()` if `deposit == 0`;
   - `InvalidTimes()` if `startTime < block.timestamp` or `stopTime <= startTime`.
   It assigns ids `0, 1, 2, ...`, stores the stream as active with `withdrawn = 0`, pulls the
   deposit from the caller and emits
   `StreamCreated(streamId, sender, recipient, token, deposit, startTime, stopTime)`.
2. `streamedAmount(id)` for an active stream:
   - `0` if `block.timestamp <= startTime`;
   - `deposit` if `block.timestamp >= stopTime`;
   - otherwise `deposit * (block.timestamp - startTime) / (stopTime - startTime)`, rounded down.
3. `withdrawable(id) = streamedAmount(id) - withdrawn`.
4. `withdraw(id, amount)`: only the recipient (`NotAuthorized()`); `ZeroAmount()` for zero;
   `InsufficientWithdrawable()` if `amount > withdrawable(id)`. It increases `withdrawn`,
   transfers the tokens to the recipient and emits `Withdrawn(streamId, recipient, amount)`.
   When `withdrawn` reaches `deposit` the stream becomes inactive.
5. `cancel(id)`: only the sender or the recipient (`NotAuthorized()`). It marks the stream
   inactive and pays
   - `recipientAmount = streamedAmount - withdrawn` to the recipient,
   - `senderAmount = deposit - streamedAmount` to the sender,
   skipping transfers of zero. Emits `StreamCancelled(streamId, recipientAmount, senderAmount)`.
6. `streamedAmount`, `withdrawable`, `withdraw` and `cancel` revert with `StreamNotActive()` for
   a stream that does not exist, was cancelled or was fully withdrawn. This check comes first.
7. Streams are independent, including several streams of the same token.
8. Token transfers that return `false` revert with `TransferFailed()`.

## What the tests check

- Accrual before the start, during the stream and after the stop time.
- Partial withdrawals and that they do not change the rate.
- Cancellation at every stage with exact conservation of the deposit.
- Authorisation, validation order, inactive streams and isolation between streams.
