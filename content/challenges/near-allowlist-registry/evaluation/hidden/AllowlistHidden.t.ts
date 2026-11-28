import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { Allowlist } from "../../src/Allowlist";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenRemoveBlocksFurtherCheckInsButKeepsHistory(): void {
  ctx("owner.testnet");
  const list = new Allowlist();
  list.add("alice.testnet");
  ctx("alice.testnet");
  list.checkIn();
  list.checkIn();

  ctx("owner.testnet");
  list.remove("alice.testnet");
  assertEq(list.isAllowed("alice.testnet"), false);
  assertEq(list.allowedCount(), 0);

  ctx("alice.testnet");
  assertThrows(() => list.checkIn(), "Not allowlisted");
  assertEq(list.checkInsOf("alice.testnet"), 2);

  // Re-adding continues from the previous count.
  ctx("owner.testnet");
  list.add("alice.testnet");
  ctx("alice.testnet");
  assertEq(list.checkIn(), 3);
}

export function testHiddenOwnerIsNotImplicitlyAllowlisted(): void {
  ctx("owner.testnet");
  const list = new Allowlist();
  assertEq(list.isAllowed("owner.testnet"), false);
  assertThrows(() => list.checkIn(), "Not allowlisted");
  list.add("owner.testnet");
  assertEq(list.checkIn(), 1);
  assertEq(list.allowedCount(), 1);
}

export function testHiddenDuplicateAndMissingEntries(): void {
  ctx("owner.testnet");
  const list = new Allowlist();
  list.add("alice.testnet");
  assertThrows(() => list.add("alice.testnet"), "Already listed");
  assertThrows(() => list.remove("bob.testnet"), "Not listed");
  assertThrows(() => list.add(""), "Invalid account");
  assertEq(list.allowedCount(), 1);

  list.add("bob.testnet");
  list.remove("alice.testnet");
  assertThrows(() => list.remove("alice.testnet"), "Not listed");
  assertEq(list.allowedCount(), 1);
  assertEq(list.isAllowed("bob.testnet"), true);
}

export function testHiddenAllowlistedAccountCannotManage(): void {
  ctx("owner.testnet");
  const list = new Allowlist();
  list.add("alice.testnet");
  ctx("alice.testnet");
  // Membership grants checkIn only, not management rights.
  assertThrows(() => list.add("bob.testnet"), "Only owner");
  assertThrows(() => list.remove("alice.testnet"), "Only owner");
  // The owner check comes before argument checks.
  assertThrows(() => list.add(""), "Only owner");
  assertThrows(() => list.remove("nobody.testnet"), "Only owner");
  assertEq(list.allowedCount(), 1);
  assertEq(list.isAllowed("bob.testnet"), false);
}
