# Prepaid Subscription Billing

## Problem Statement

Implement `SubscriptionBilling` in `src/SubscriptionBilling.sol`: prepaid recurring billing in ETH
for one merchant.

A contract cannot pull ETH out of a user's wallet, so subscribers deposit in advance. The
deployer is the `merchant` and fixes a `price` per `period`. Each period is paid in advance: the
first one when subscribing, every following one when the merchant calls `charge`.

## Required Interface

```solidity
constructor(uint256 _price, uint256 _period)      // provided

function subscribe() external payable
function topUp() external payable
function charge(address subscriber) external
function cancel(address subscriber) external
function withdraw() external
function collect() external
function isPaid(address subscriber) external view returns (bool)

// public state (already declared in the starter)
address public immutable merchant;
uint256 public immutable price;
uint256 public immutable period;
uint256 public merchantBalance;
mapping(address => Subscription) public subscriptions;   // (balance, paidUntil, active)
```

## Rules

1. `subscribe()`
   - reverts with `AlreadySubscribed()` if the caller's subscription is active;
   - adds `msg.value` to the caller's balance (a balance left over from an earlier subscription
     counts too) and reverts with `InsufficientBalance()` if the balance is then below `price`;
   - charges the first period immediately: moves `price` from the subscriber's balance to
     `merchantBalance`, sets `paidUntil = block.timestamp + period` and `active = true`;
   - emits `Subscribed(subscriber, paidUntil)`.
2. `topUp()` adds `msg.value` to the caller's balance. It reverts with `ZeroAmount()` for a zero
   value. It does not require an active subscription.
3. `charge(subscriber)`
   - reverts with `NotMerchant()` unless called by the merchant;
   - reverts with `NotSubscribed()` if the subscription is not active;
   - reverts with `NotDue()` while `block.timestamp < paidUntil`;
   - reverts with `InsufficientBalance()` if the subscriber's balance is below `price`;
   - moves `price` to `merchantBalance` and sets `paidUntil = paidUntil + period` (the previous
     value plus one period, not the current time plus one period);
   - emits `Charged(subscriber, paidUntil)`.
   If several periods have gone by unbilled, the merchant may call `charge` repeatedly; each call
   bills exactly one period, until `paidUntil` is in the future again.
4. `cancel(subscriber)`
   - reverts with `NotAuthorized()` unless the caller is `subscriber` or the merchant;
   - reverts with `NotSubscribed()` if the subscription is not active;
   - sets `active = false` and emits `Cancelled(subscriber, msg.sender)`. Nothing already charged
     is refunded, and nothing more can be charged.
5. `withdraw()` pays the caller their whole remaining balance. It reverts with
   `StillSubscribed()` while their subscription is active and with `NothingToWithdraw()` if the
   balance is zero.
6. `collect()` pays `merchantBalance` to the merchant and zeroes it. It reverts with
   `NotMerchant()` for other callers and `NothingToWithdraw()` if the balance is zero.
7. `isPaid(subscriber)` is `true` exactly when the subscription is active and
   `block.timestamp < paidUntil`.
8. Any failed ETH transfer reverts with `TransferFailed()`. The checks must be evaluated in the
   order listed.

## What the Tests Check

- Public tests: subscribing, charging a due period, cancellation and withdrawal, merchant
  collection.
- Hidden tests: charging early or twice in one period, late and catch-up charges, insufficient
  balances and top-ups, access control, cancellation by each side, re-subscribing with a leftover
  balance, and that the merchant can never take more than was charged.
