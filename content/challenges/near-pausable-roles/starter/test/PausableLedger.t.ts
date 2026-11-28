import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { PausableLedger } from "../src/PausableLedger";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testDepositAndWithdraw(): void {
  ctx("admin.testnet");
  const ledger = new PausableLedger();
  ctx("alice.testnet", 1000n, 100n);
  assertEq(ledger.deposit(), 100n);
  ctx("alice.testnet", 1001n, 50n);
  assertEq(ledger.deposit(), 150n);
  ctx("alice.testnet", 1002n);
  assertEq(ledger.withdraw(60n), 90n);
  assertEq(ledger.balanceOf("alice.testnet"), 90n);
}

export function testPauseBlocksDeposits(): void {
  ctx("admin.testnet");
  const ledger = new PausableLedger();
  ledger.pause();
  assertEq(ledger.isPaused(), true);
  ctx("alice.testnet", 1000n, 100n);
  assertThrows(() => ledger.deposit(), "Contract is paused");
  assertEq(ledger.balanceOf("alice.testnet"), 0n);

  ctx("admin.testnet");
  ledger.unpause();
  ctx("alice.testnet", 1000n, 100n);
  assertEq(ledger.deposit(), 100n);
}

export function testPauserCanPauseButNotUnpause(): void {
  ctx("admin.testnet");
  const ledger = new PausableLedger();
  ledger.setPauser("guardian.testnet");
  assertEq(ledger.getPauser(), "guardian.testnet");

  ctx("guardian.testnet");
  ledger.pause();
  assertEq(ledger.isPaused(), true);
  assertThrows(() => ledger.unpause(), "Only admin");
  assertEq(ledger.isPaused(), true);
}

export function testStrangerCannotPause(): void {
  ctx("admin.testnet");
  const ledger = new PausableLedger();
  ctx("mallory.testnet");
  assertThrows(() => ledger.pause(), "Not authorized");
  assertEq(ledger.isPaused(), false);
}
