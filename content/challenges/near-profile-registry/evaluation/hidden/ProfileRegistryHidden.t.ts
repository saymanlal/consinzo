import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { ProfileRegistry } from "../../src/ProfileRegistry";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenAccountsAreIsolated(): void {
  const registry = new ProfileRegistry();
  ctx("alice.testnet");
  registry.setProfile("Alice", "a");
  ctx("bob.testnet");
  registry.setProfile("Bob", "b");
  assertEq(registry.profileCount(), 2);

  // Bob deleting removes only Bob's profile.
  registry.deleteProfile();
  assertEq(registry.getProfile("bob.testnet"), null);
  assertEq(registry.getProfile("alice.testnet")?.name, "Alice");
  assertEq(registry.profileCount(), 1);

  // Bob has nothing left to delete and cannot delete Alice's entry.
  assertThrows(() => registry.deleteProfile(), "Profile not found");
  assertEq(registry.profileCount(), 1);
}

export function testHiddenLengthBoundaries(): void {
  const registry = new ProfileRegistry();
  ctx("alice.testnet");
  assertThrows(() => registry.setProfile("", "bio"), "Invalid name");
  assertThrows(() => registry.setProfile("n".repeat(33), "bio"), "Invalid name");
  assertThrows(() => registry.setProfile("ok", "b".repeat(161)), "Bio too long");
  assertEq(registry.profileCount(), 0);
  assertEq(registry.getProfile("alice.testnet"), null);

  registry.setProfile("n".repeat(32), "b".repeat(160));
  assertEq(registry.getProfile("alice.testnet")?.name.length, 32);
  assertEq(registry.getProfile("alice.testnet")?.bio.length, 160);
  assertEq(registry.profileCount(), 1);
}

export function testHiddenFailedUpdateKeepsOldProfile(): void {
  const registry = new ProfileRegistry();
  ctx("alice.testnet", 10n);
  registry.setProfile("Alice", "first");
  ctx("alice.testnet", 20n);
  assertThrows(() => registry.setProfile("", "second"), "Invalid name");
  assertEq(registry.getProfile("alice.testnet")?.bio, "first");
  assertEq(registry.getProfile("alice.testnet")?.updatedAt, 10n);
  assertEq(registry.profileCount(), 1);
}

export function testHiddenRecreateAfterDelete(): void {
  const registry = new ProfileRegistry();
  ctx("alice.testnet", 10n);
  registry.setProfile("Alice", "v1");
  registry.deleteProfile();
  ctx("alice.testnet", 30n);
  registry.setProfile("Alice2", "v2");
  assertEq(registry.profileCount(), 1);
  assertEq(registry.getProfile("alice.testnet")?.name, "Alice2");
  assertEq(registry.getProfile("alice.testnet")?.updatedAt, 30n);
  registry.deleteProfile();
  assertEq(registry.profileCount(), 0);
}
