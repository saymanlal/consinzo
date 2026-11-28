import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { PausableLedger } from "../../src/PausableLedger";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenWithdrawWorksWhilePaused(): void {
  ctx("admin.testnet");
  const ledger = new PausableLedger();
  ctx("alice.testnet", 1n, 500n);
  ledger.deposit();
  ctx("admin.testnet");
  ledger.pause();

  ctx("alice.testnet");
  assertEq(ledger.withdraw(200n), 300n);
  assertThrows(() => ledger.withdraw(301n), "Insufficient balance");
  assertThrows(() => ledger.withdraw(0n), "Amount must be positive");
  assertThrows(() => ledger.withdraw(-1n), "Amount must be positive");
  assertEq(ledger.withdraw(300n), 0n);
  assertEq(ledger.balanceOf("alice.testnet"), 0n);
  assertEq(ledger.isPaused(), true);
}

export function testHiddenStateChecks(): void {
  ctx("admin.testnet");
  const ledger = new PausableLedger();
  assertThrows(() => ledger.unpause(), "Not paused");
  ledger.pause();
  assertThrows(() => ledger.pause(), "Already paused");
  ledger.unpause();
  assertEq(ledger.isPaused(), false);
  ledger.pause();
  assertEq(ledger.isPaused(), true);
}

export function testHiddenRoleChecksComeBeforeStateChecks(): void {
  ctx("admin.testnet");
  const ledger = new PausableLedger();
  ledger.setPauser("guardian.testnet");
  ledger.pause();

  ctx("mallory.testnet");
  // Already paused, but an outsider still gets the role error.
  assertThrows(() => ledger.pause(), "Not authorized");
  assertThrows(() => ledger.unpause(), "Only admin");
  assertThrows(() => ledger.setPauser("mallory.testnet"), "Only admin");
  assertThrows(() => ledger.transferAdmin(""), "Only admin");
  ctx("guardian.testnet");
  assertThrows(() => ledger.pause(), "Already paused");
  assertThrows(() => ledger.setPauser("guardian2.testnet"), "Only admin");
  assertEq(ledger.getPauser(), "guardian.testnet");
}

export function testHiddenReplacingAndRemovingPauser(): void {
  ctx("admin.testnet");
  const ledger = new PausableLedger();
  assertEq(ledger.getPauser(), "");
  ledger.setPauser("g1.testnet");
  ledger.setPauser("g2.testnet");

  ctx("g1.testnet");
  assertThrows(() => ledger.pause(), "Not authorized");
  ctx("g2.testnet");
  ledger.pause();
  ctx("admin.testnet");
  ledger.unpause();
  ledger.setPauser("");
  assertEq(ledger.getPauser(), "");
  ctx("g2.testnet");
  assertThrows(() => ledger.pause(), "Not authorized");
  assertEq(ledger.isPaused(), false);
}

export function testHiddenAdminHandover(): void {
  ctx("admin.testnet");
  const ledger = new PausableLedger();
  assertThrows(() => ledger.transferAdmin(""), "Invalid admin");
  ledger.transferAdmin("admin2.testnet");
  assertEq(ledger.getAdmin(), "admin2.testnet");

  // The old admin has no rights left.
  assertThrows(() => ledger.pause(), "Not authorized");
  assertThrows(() => ledger.setPauser("admin.testnet"), "Only admin");
  ctx("admin2.testnet");
  ledger.pause();
  ledger.unpause();
  ledger.setPauser("guardian.testnet");
  assertEq(ledger.getPauser(), "guardian.testnet");
}

export function testHiddenDepositValidationAndIsolation(): void {
  ctx("admin.testnet");
  const ledger = new PausableLedger();
  ctx("alice.testnet", 1n, 0n);
  assertThrows(() => ledger.deposit(), "Deposit required");
  ctx("alice.testnet", 1n, 10n);
  ledger.deposit();
  ctx("bob.testnet");
  assertThrows(() => ledger.withdraw(1n), "Insufficient balance");
  assertEq(ledger.balanceOf("alice.testnet"), 10n);

  // While paused the pause error takes precedence over the deposit check.
  ctx("admin.testnet");
  ledger.pause();
  ctx("alice.testnet", 2n, 0n);
  assertThrows(() => ledger.deposit(), "Contract is paused");
}
