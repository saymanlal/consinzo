import { near, assertEq, assertThrows } from "near-sdk-js";
import { VestingVault } from "../src/VestingVault";

function caller(who: string, deposit: bigint = 0n): void {
  near._setContext({ predecessorAccountId: who, signerAccountId: who, attachedDeposit: deposit });
}

function time(now: bigint): void {
  near._setContext({ blockTimestamp: now });
}

export function testCliffThenLinearRelease(): void {
  const vault = new VestingVault();
  time(1000n);
  caller("grantor.testnet", 1200n);
  const id = vault.createGrant("bob.testnet", 1000n, 300n, 1200n, true);
  assertEq(id, 1);

  caller("bob.testnet");
  time(1299n);
  assertEq(vault.vestedAmount(id), 0n);
  assertThrows(() => vault.release(id), "Nothing to release");

  time(1300n);
  assertEq(vault.vestedAmount(id), 300n);

  time(1600n);
  assertEq(vault.releasable(id), 600n);
  assertEq(vault.release(id), 600n);
  assertEq(vault.balanceOf("bob.testnet"), 600n);
  assertEq(vault.releasable(id), 0n);

  time(2200n);
  assertEq(vault.vestedAmount(id), 1200n);
  assertEq(vault.release(id), 600n);
  assertEq(vault.balanceOf("bob.testnet"), 1200n);

  time(9999n);
  assertThrows(() => vault.release(id), "Nothing to release");
}

export function testRevokeReturnsUnvestedToGrantor(): void {
  const vault = new VestingVault();
  time(1000n);
  caller("grantor.testnet", 1200n);
  const id = vault.createGrant("bob.testnet", 1000n, 300n, 1200n, true);

  time(1600n);
  assertEq(vault.revoke(id), 600n);
  assertEq(vault.balanceOf("grantor.testnet"), 600n);

  // The schedule is frozen: more time does not vest more.
  time(5000n);
  assertEq(vault.vestedAmount(id), 600n);
  caller("bob.testnet");
  assertEq(vault.release(id), 600n);
  assertEq(vault.balanceOf("bob.testnet"), 600n);
}

export function testAccessControl(): void {
  const vault = new VestingVault();
  time(1000n);
  caller("grantor.testnet", 500n);
  const fixed = vault.createGrant("bob.testnet", 1000n, 0n, 100n, false);
  assertThrows(() => vault.revoke(fixed), "Not revocable");

  time(1050n);
  caller("mallory.testnet");
  assertThrows(() => vault.release(fixed), "Not beneficiary");
  assertThrows(() => vault.revoke(fixed), "Not grantor");
  assertEq(vault.balanceOf("mallory.testnet"), 0n);
}
