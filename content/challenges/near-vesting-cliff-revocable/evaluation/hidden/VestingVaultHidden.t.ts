import { near, assertEq, assertThrows } from "near-sdk-js";
import { VestingVault } from "../../src/VestingVault";

function caller(who: string, deposit: bigint = 0n): void {
  near._setContext({ predecessorAccountId: who, signerAccountId: who, attachedDeposit: deposit });
}

function time(now: bigint): void {
  near._setContext({ blockTimestamp: now });
}

export function testHiddenRoundingNeverOverpays(): void {
  const vault = new VestingVault();
  time(10n);
  caller("grantor.testnet", 1000n);
  const id = vault.createGrant("bob.testnet", 10n, 0n, 3n, true);

  caller("bob.testnet");
  assertThrows(() => vault.release(id), "Nothing to release");
  time(11n);
  assertEq(vault.release(id), 333n);
  time(12n);
  assertEq(vault.release(id), 333n);
  time(13n);
  assertEq(vault.release(id), 334n);
  assertEq(vault.balanceOf("bob.testnet"), 1000n);
  assertEq(vault.getGrant(id)?.released, 1000n);
}

export function testHiddenStartInFutureVestsNothing(): void {
  const vault = new VestingVault();
  time(100n);
  caller("grantor.testnet", 900n);
  const id = vault.createGrant("bob.testnet", 5000n, 0n, 900n, true);
  assertEq(vault.vestedAmount(id), 0n);
  time(4999n);
  assertEq(vault.vestedAmount(id), 0n);
  time(5001n);
  assertEq(vault.vestedAmount(id), 1n);
  time(5900n);
  assertEq(vault.vestedAmount(id), 900n);
}

export function testHiddenRevokeAfterPartialRelease(): void {
  const vault = new VestingVault();
  time(1000n);
  caller("grantor.testnet", 1200n);
  const id = vault.createGrant("bob.testnet", 1000n, 300n, 1200n, true);

  time(1300n);
  caller("bob.testnet");
  assertEq(vault.release(id), 300n);

  time(1600n);
  caller("grantor.testnet");
  assertEq(vault.revoke(id), 600n);
  assertThrows(() => vault.revoke(id), "Already revoked");
  assertEq(vault.getGrant(id)?.revoked, true);
  assertEq(vault.getGrant(id)?.total, 600n);

  time(8000n);
  caller("bob.testnet");
  assertEq(vault.releasable(id), 300n);
  assertEq(vault.release(id), 300n);
  assertThrows(() => vault.release(id), "Nothing to release");
  assertEq(vault.balanceOf("bob.testnet") + vault.balanceOf("grantor.testnet"), 1200n);
}

export function testHiddenRevokeBeforeCliffAndAfterEnd(): void {
  const vault = new VestingVault();
  time(1000n);
  caller("grantor.testnet", 800n);
  const early = vault.createGrant("bob.testnet", 1000n, 400n, 800n, true);
  caller("grantor.testnet", 700n);
  const late = vault.createGrant("carol.testnet", 1000n, 0n, 100n, true);
  assertEq(late, 2);

  time(1399n);
  caller("grantor.testnet");
  assertEq(vault.revoke(early), 800n);
  assertEq(vault.vestedAmount(early), 0n);
  caller("bob.testnet");
  time(3000n);
  assertThrows(() => vault.release(early), "Nothing to release");

  // Revoking a fully vested grant returns nothing and leaves the beneficiary whole.
  caller("grantor.testnet");
  assertEq(vault.revoke(late), 0n);
  assertEq(vault.balanceOf("grantor.testnet"), 800n);
  caller("carol.testnet");
  assertEq(vault.release(late), 700n);
}

export function testHiddenValidation(): void {
  const vault = new VestingVault();
  time(1000n);
  caller("grantor.testnet", 0n);
  assertThrows(() => vault.createGrant("bob.testnet", 1000n, 0n, 100n, true), "Invalid grant");
  caller("grantor.testnet", 100n);
  assertThrows(() => vault.createGrant("", 1000n, 0n, 100n, true), "Invalid grant");
  assertThrows(() => vault.createGrant("grantor.testnet", 1000n, 0n, 100n, true), "Invalid grant");
  assertThrows(() => vault.createGrant("bob.testnet", 1000n, 0n, 0n, true), "Invalid grant");
  assertThrows(() => vault.createGrant("bob.testnet", 1000n, 101n, 100n, true), "Invalid grant");

  // A cliff equal to the duration is allowed: everything unlocks at once.
  const id = vault.createGrant("bob.testnet", 1000n, 100n, 100n, true);
  assertEq(id, 1);
  time(1099n);
  assertEq(vault.vestedAmount(id), 0n);
  time(1100n);
  assertEq(vault.vestedAmount(id), 100n);

  assertThrows(() => vault.vestedAmount(7), "Grant not found");
  assertThrows(() => vault.release(7), "Grant not found");
  assertThrows(() => vault.revoke(7), "Grant not found");
  assertEq(vault.getGrant(7), null);
}
