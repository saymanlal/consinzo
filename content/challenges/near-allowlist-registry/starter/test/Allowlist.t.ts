import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { Allowlist } from "../src/Allowlist";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testOwnerAddsAndAllowedAccountChecksIn(): void {
  ctx("owner.testnet");
  const list = new Allowlist();
  list.add("alice.testnet");
  assertEq(list.isAllowed("alice.testnet"), true);
  assertEq(list.allowedCount(), 1);

  ctx("alice.testnet");
  assertEq(list.checkIn(), 1);
  assertEq(list.checkIn(), 2);
  assertEq(list.checkInsOf("alice.testnet"), 2);
}

export function testUnlistedAccountCannotCheckIn(): void {
  ctx("owner.testnet");
  const list = new Allowlist();
  list.add("alice.testnet");
  ctx("bob.testnet");
  assertThrows(() => list.checkIn(), "Not allowlisted");
  assertEq(list.checkInsOf("bob.testnet"), 0);
}

export function testOnlyOwnerManagesList(): void {
  ctx("owner.testnet");
  const list = new Allowlist();
  ctx("bob.testnet");
  assertThrows(() => list.add("bob.testnet"), "Only owner");
  assertEq(list.isAllowed("bob.testnet"), false);
  assertEq(list.allowedCount(), 0);
}
