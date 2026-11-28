import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { RegisteredNotes } from "../src/RegisteredNotes";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testRegisterThenSetNote(): void {
  ctx("owner.testnet");
  const notes = new RegisteredNotes(100n);
  ctx("alice.testnet", 1000n, 100n);
  notes.register();
  assertEq(notes.isRegistered("alice.testnet"), true);
  assertEq(notes.storageBalanceOf("alice.testnet"), 100n);
  assertEq(notes.totalStorageHeld(), 100n);

  ctx("alice.testnet");
  notes.setNote("hello");
  assertEq(notes.getNote("alice.testnet"), "hello");
}

export function testUnregisteredAccountCannotSetNote(): void {
  ctx("owner.testnet");
  const notes = new RegisteredNotes(100n);
  ctx("bob.testnet");
  assertThrows(() => notes.setNote("hi"), "Not registered");
  assertEq(notes.getNote("bob.testnet"), null);
}

export function testInsufficientDepositRejected(): void {
  ctx("owner.testnet");
  const notes = new RegisteredNotes(100n);
  ctx("alice.testnet", 1000n, 99n);
  assertThrows(() => notes.register(), "Insufficient storage deposit");
  assertEq(notes.isRegistered("alice.testnet"), false);
  assertEq(notes.totalStorageHeld(), 0n);
}

export function testUnregisterRefundsFee(): void {
  ctx("owner.testnet");
  const notes = new RegisteredNotes(100n);
  ctx("alice.testnet", 1000n, 100n);
  notes.register();
  ctx("alice.testnet");
  notes.setNote("bye");
  assertEq(notes.unregister(), 100n);
  assertEq(notes.isRegistered("alice.testnet"), false);
  assertEq(notes.getNote("alice.testnet"), null);
  assertEq(notes.refundableOf("alice.testnet"), 100n);
  assertEq(notes.claimRefund(), 100n);
  assertEq(notes.refundableOf("alice.testnet"), 0n);
}
