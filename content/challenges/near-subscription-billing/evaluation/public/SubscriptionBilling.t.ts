import { near, assertEq, assertThrows } from "near-sdk-js";
import { SubscriptionBilling } from "../src/SubscriptionBilling";

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
  assertEq(billing.createPlan(100n, 1000n), 1);
  return billing;
}

export function testSubscribeChargesFirstPeriod(): void {
  const billing = setup();
  caller("alice.testnet", 350n);
  billing.fund();
  caller("alice.testnet");
  billing.subscribe(1);

  assertEq(billing.balanceOf("alice.testnet"), 250n);
  assertEq(billing.earnings(), 100n);
  assertEq(billing.getSubscription("alice.testnet")?.paidUntil, 11000n);
  assertEq(billing.isActive("alice.testnet"), true);
  time(11000n);
  assertEq(billing.isActive("alice.testnet"), false);
}

export function testKeeperCatchesUpAndLapses(): void {
  const billing = setup();
  caller("alice.testnet", 350n);
  billing.fund();
  caller("alice.testnet");
  billing.subscribe(1);

  // Two periods became due at 11000 and 12000.
  time(12500n);
  caller("keeper.testnet");
  assertEq(billing.charge("alice.testnet"), 2);
  assertEq(billing.balanceOf("alice.testnet"), 50n);
  assertEq(billing.getSubscription("alice.testnet")?.paidUntil, 13000n);
  assertEq(billing.isActive("alice.testnet"), true);
  assertEq(billing.charge("alice.testnet"), 0);

  // 50 left cannot pay the period due at 13000.
  time(13000n);
  assertEq(billing.charge("alice.testnet"), 0);
  assertEq(billing.getSubscription("alice.testnet")?.status, "LAPSED");
  assertEq(billing.balanceOf("alice.testnet"), 50n);
  assertEq(billing.isActive("alice.testnet"), false);
  assertEq(billing.earnings(), 300n);
}

export function testCancelTakesEffectAtPeriodEnd(): void {
  const billing = setup();
  caller("alice.testnet", 500n);
  billing.fund();
  caller("alice.testnet");
  billing.subscribe(1);

  time(10500n);
  billing.cancel();
  time(10999n);
  assertEq(billing.isActive("alice.testnet"), true);

  time(11500n);
  assertEq(billing.isActive("alice.testnet"), false);
  caller("keeper.testnet");
  assertEq(billing.charge("alice.testnet"), 0);
  assertEq(billing.getSubscription("alice.testnet")?.status, "CANCELLED");
  assertEq(billing.balanceOf("alice.testnet"), 400n);

  caller("alice.testnet");
  assertEq(billing.withdrawBalance(400n), 400n);
  assertEq(billing.balanceOf("alice.testnet"), 0n);
}

export function testOnlyOwnerManagesPlansAndEarnings(): void {
  const billing = setup();
  caller("mallory.testnet");
  assertThrows(() => billing.createPlan(1n, 1n), "Not owner");
  assertThrows(() => billing.collectEarnings(), "Not owner");
}
