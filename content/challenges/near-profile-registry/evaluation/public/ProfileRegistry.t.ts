import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { ProfileRegistry } from "../src/ProfileRegistry";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testSetAndGetOwnProfile(): void {
  const registry = new ProfileRegistry();
  ctx("alice.testnet", 4000n);
  registry.setProfile("Alice", "builds on near");

  const profile = registry.getProfile("alice.testnet");
  assertEq(profile?.name, "Alice");
  assertEq(profile?.bio, "builds on near");
  assertEq(profile?.updatedAt, 4000n);
  assertEq(registry.getProfile("bob.testnet"), null);
  assertEq(registry.profileCount(), 1);
}

export function testUpdateDoesNotChangeCount(): void {
  const registry = new ProfileRegistry();
  ctx("alice.testnet", 100n);
  registry.setProfile("Alice", "");
  ctx("alice.testnet", 200n);
  registry.setProfile("Alice B", "new bio");

  assertEq(registry.profileCount(), 1);
  assertEq(registry.getProfile("alice.testnet")?.name, "Alice B");
  assertEq(registry.getProfile("alice.testnet")?.updatedAt, 200n);
}

export function testDeleteOwnProfile(): void {
  const registry = new ProfileRegistry();
  ctx("alice.testnet");
  registry.setProfile("Alice", "hi");
  registry.deleteProfile();
  assertEq(registry.getProfile("alice.testnet"), null);
  assertEq(registry.profileCount(), 0);
  assertThrows(() => registry.deleteProfile(), "Profile not found");
}
