import { near, assertEq, assertThrows } from "near-sdk-js";
import { SubscriptionBilling } from "../../src/SubscriptionBilling";

function caller(who: string, deposit: bigint = 0n): void {
  near._setContext({ predecessorAccountId: who, signerAccountId: who, attachedDeposit: deposit });
}

function time(now: bigint): void {
  near._setContext({ blockTimestamp: now });
}

function setup(): SubscriptionBilling {
  time(10000n);
  caller("merchant.testnet");
  const billing = new SubscriptionBilling();
  billing.createPlan(100n, 1000n);
  billing.createPlan(30n, 250n);
  return billing;
}

function fundAndSubscribe(b: SubscriptionBilling, who: string, amount: bigint, plan: number): void {
  caller(who, amount);
  b.fund();
  caller(who);
  b.subscribe(plan);
}

export function testHiddenWithdrawSettlesDuePeriodsFirst(): void {
  const billing = setup();
  fundAndSubscribe(billing, "alice.testnet", 200n, 1);
  assertEq(billing.balanceOf("alice.testnet"), 100n);

  // A period is due at 11000. Withdrawing must not dodge it.
  time(11500n);
  caller("alice.testnet");
  assertThrows(() => billing.withdrawBalance(100n), "Insufficient balance");
  assertEq(billing.earnings(), 200n);
  assertEq(billing.balanceOf("alice.testnet"), 0n);
  assertEq(billing.getSubscription("alice.testnet")?.paidUntil, 12000n);
}

export function testHiddenCatchUpStopsAtLapse(): void {
  const billing = setup();
  fundAndSubscribe(billing, "alice.testnet", 250n, 1);

  // Three periods are due (11000, 12000, 13000) but only one can be paid.
  time(13500n);
  caller("keeper.testnet");
  assertEq(billing.charge("alice.testnet"), 1);
  const sub = billing.getSubscription("alice.testnet");
  assertEq(sub?.status, "LAPSED");
  assertEq(sub?.paidUntil, 12000n);
  assertEq(billing.balanceOf("alice.testnet"), 50n);
  assertEq(billing.earnings(), 200n);

  // Topping up does not revive a lapsed subscription or back-bill it.
  caller("alice.testnet", 500n);
  billing.fund();
  caller("keeper.testnet");
  assertEq(billing.charge("alice.testnet"), 0);
  assertEq(billing.balanceOf("alice.testnet"), 550n);

  // Subscribing again starts a fresh period from now.
  caller("alice.testnet");
  billing.subscribe(2);
  assertEq(billing.balanceOf("alice.testnet"), 520n);
  assertEq(billing.getSubscription("alice.testnet")?.paidUntil, 13750n);
  assertEq(billing.getSubscription("alice.testnet")?.planId, 2);
  assertEq(billing.isActive("alice.testnet"), true);
}

export function testHiddenPaidUntilAdvancesFromDueDate(): void {
  const billing = setup();
  fundAndSubscribe(billing, "alice.testnet", 1000n, 2);
  assertEq(billing.getSubscription("alice.testnet")?.paidUntil, 10250n);

  // Exactly at the boundary one period is due.
  time(10250n);
  caller("keeper.testnet");
  assertEq(billing.charge("alice.testnet"), 1);
  assertEq(billing.getSubscription("alice.testnet")?.paidUntil, 10500n);

  // A late keeper does not shift the schedule.
  time(10999n);
  assertEq(billing.charge("alice.testnet"), 2);
  assertEq(billing.getSubscription("alice.testnet")?.paidUntil, 11000n);
  assertEq(billing.balanceOf("alice.testnet"), 1000n - 4n * 30n);
}

export function testHiddenSubscribeGuards(): void {
  const billing = setup();
  caller("alice.testnet", 99n);
  billing.fund();
  caller("alice.testnet");
  assertThrows(() => billing.subscribe(9), "Plan not found");
  assertThrows(() => billing.subscribe(1), "Insufficient balance");
  assertEq(billing.getSubscription("alice.testnet"), null);
  assertEq(billing.earnings(), 0n);

  caller("alice.testnet", 201n);
  billing.fund();
  caller("alice.testnet");
  billing.subscribe(1);
  assertThrows(() => billing.subscribe(1), "Already subscribed");
  assertThrows(() => billing.subscribe(2), "Already subscribed");
  assertEq(billing.balanceOf("alice.testnet"), 200n);

  // Still ACTIVE after the period rolls over because the balance covers it.
  time(11000n);
  assertThrows(() => billing.subscribe(2), "Already subscribed");
  assertEq(billing.balanceOf("alice.testnet"), 100n);

  caller("alice.testnet", 0n);
  assertThrows(() => billing.fund(), "Zero deposit");
  caller("keeper.testnet");
  assertThrows(() => billing.charge("nobody.testnet"), "No subscription");
}

export function testHiddenCancelRules(): void {
  const billing = setup();
  caller("bob.testnet");
  assertThrows(() => billing.cancel(), "No active subscription");

  fundAndSubscribe(billing, "bob.testnet", 300n, 1);
  time(10100n);
  billing.cancel();
  assertEq(billing.getSubscription("bob.testnet")?.cancelRequested, true);
  // Cancelling does not refund the running period.
  assertEq(billing.balanceOf("bob.testnet"), 200n);

  // Several periods later nothing more was charged.
  time(15000n);
  caller("keeper.testnet");
  assertEq(billing.charge("bob.testnet"), 0);
  assertEq(billing.balanceOf("bob.testnet"), 200n);
  assertEq(billing.getSubscription("bob.testnet")?.status, "CANCELLED");
  caller("bob.testnet");
  assertThrows(() => billing.cancel(), "No active subscription");

  // Re-subscribing clears the cancellation flag.
  billing.subscribe(1);
  assertEq(billing.getSubscription("bob.testnet")?.cancelRequested, false);
  assertEq(billing.getSubscription("bob.testnet")?.paidUntil, 16000n);
  assertEq(billing.balanceOf("bob.testnet"), 100n);
}

export function testHiddenEarningsCollection(): void {
  const billing = setup();
  fundAndSubscribe(billing, "alice.testnet", 100n, 1);
  fundAndSubscribe(billing, "bob.testnet", 60n, 2);
  assertEq(billing.earnings(), 130n);

  caller("alice.testnet");
  assertThrows(() => billing.collectEarnings(), "Not owner");
  assertThrows(() => billing.withdrawBalance(0n), "Insufficient balance");
  assertThrows(() => billing.withdrawBalance(1n), "Insufficient balance");
  caller("bob.testnet");
  assertEq(billing.withdrawBalance(30n), 30n);

  caller("merchant.testnet");
  assertEq(billing.collectEarnings(), 130n);
  assertEq(billing.earnings(), 0n);
  assertEq(billing.collectEarnings(), 0n);
  assertThrows(() => billing.createPlan(0n, 10n), "Invalid plan");
  assertThrows(() => billing.createPlan(10n, 0n), "Invalid plan");
  assertEq(billing.createPlan(5n, 5n), 3);
  assertEq(billing.getPlan(3)?.price, 5n);
}
