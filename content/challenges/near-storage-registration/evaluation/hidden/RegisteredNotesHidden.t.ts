import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { RegisteredNotes } from "../../src/RegisteredNotes";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenExcessDepositIsRefundable(): void {
  ctx("owner.testnet");
  const notes = new RegisteredNotes(100n);
  ctx("alice.testnet", 1000n, 250n);
  notes.register();
  assertEq(notes.storageBalanceOf("alice.testnet"), 100n);
  assertEq(notes.refundableOf("alice.testnet"), 150n);
  assertEq(notes.totalStorageHeld(), 100n);

  // The excess can be claimed while staying registered.
  ctx("alice.testnet");
  assertEq(notes.claimRefund(), 150n);
  assertEq(notes.isRegistered("alice.testnet"), true);
  assertThrows(() => notes.claimRefund(), "Nothing to refund");
  notes.setNote("still here");
  assertEq(notes.getNote("alice.testnet"), "still here");
}

export function testHiddenRefundUsesRecordedFeeAfterFeeChange(): void {
  ctx("owner.testnet");
  const notes = new RegisteredNotes(100n);
  ctx("alice.testnet", 1000n, 100n);
  notes.register();

  ctx("owner.testnet");
  notes.setStorageFee(300n);
  assertEq(notes.getStorageFee(), 300n);
  // Alice's recorded balance does not move with the fee.
  assertEq(notes.storageBalanceOf("alice.testnet"), 100n);

  ctx("bob.testnet", 1000n, 299n);
  assertThrows(() => notes.register(), "Insufficient storage deposit");
  ctx("bob.testnet", 1000n, 300n);
  notes.register();
  assertEq(notes.totalStorageHeld(), 400n);

  ctx("owner.testnet");
  notes.setStorageFee(50n);
  ctx("alice.testnet");
  assertEq(notes.unregister(), 100n);
  ctx("bob.testnet");
  assertEq(notes.unregister(), 300n);
  assertEq(notes.refundableOf("alice.testnet"), 100n);
  assertEq(notes.refundableOf("bob.testnet"), 300n);
  assertEq(notes.totalStorageHeld(), 0n);
}

export function testHiddenDoubleRegisterAndDoubleUnregister(): void {
  ctx("owner.testnet");
  const notes = new RegisteredNotes(100n);
  ctx("alice.testnet", 1000n, 100n);
  notes.register();
  ctx("alice.testnet", 1001n, 100n);
  assertThrows(() => notes.register(), "Already registered");
  assertEq(notes.totalStorageHeld(), 100n);
  assertEq(notes.refundableOf("alice.testnet"), 0n);

  ctx("alice.testnet");
  notes.unregister();
  assertThrows(() => notes.unregister(), "Not registered");
  assertEq(notes.refundableOf("alice.testnet"), 100n);
  assertThrows(() => notes.setNote("x"), "Not registered");
}

export function testHiddenReRegisterStartsCleanAndRefundsAccumulate(): void {
  ctx("owner.testnet");
  const notes = new RegisteredNotes(100n);
  ctx("alice.testnet", 1000n, 120n);
  notes.register();
  ctx("alice.testnet");
  notes.setNote("old note");
  notes.unregister();
  // 20 excess + 100 fee are waiting, unclaimed.
  assertEq(notes.refundableOf("alice.testnet"), 120n);

  ctx("alice.testnet", 2000n, 100n);
  notes.register();
  assertEq(notes.getNote("alice.testnet"), null);
  assertEq(notes.refundableOf("alice.testnet"), 120n);
  ctx("alice.testnet");
  notes.unregister();
  assertEq(notes.refundableOf("alice.testnet"), 220n);
  assertEq(notes.claimRefund(), 220n);
  assertThrows(() => notes.claimRefund(), "Nothing to refund");
  assertEq(notes.totalStorageHeld(), 0n);
}

export function testHiddenFeeAdministrationAndNoteValidation(): void {
  ctx("owner.testnet");
  assertThrows(() => new RegisteredNotes(0n), "Invalid fee");
  const notes = new RegisteredNotes(10n);
  assertThrows(() => notes.setStorageFee(0n), "Invalid fee");
  ctx("mallory.testnet");
  assertThrows(() => notes.setStorageFee(1n), "Only owner");
  assertThrows(() => notes.claimRefund(), "Nothing to refund");
  assertEq(notes.getStorageFee(), 10n);

  ctx("alice.testnet", 1000n, 10n);
  notes.register();
  ctx("alice.testnet");
  assertThrows(() => notes.setNote(""), "Invalid note");
  assertThrows(() => notes.setNote("n".repeat(201)), "Invalid note");
  notes.setNote("n".repeat(200));
  notes.setNote("short");
  assertEq(notes.getNote("alice.testnet"), "short");
  // Bob cannot unregister or read rights from Alice's registration.
  ctx("bob.testnet");
  assertThrows(() => notes.unregister(), "Not registered");
  assertEq(notes.storageBalanceOf("bob.testnet"), 0n);
  assertEq(notes.isRegistered("alice.testnet"), true);
}
