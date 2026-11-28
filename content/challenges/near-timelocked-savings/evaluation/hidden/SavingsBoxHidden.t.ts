import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { SavingsBox } from "../../src/SavingsBox";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenNewBoxNeedsFutureUnlock(): void {
  const savings = new SavingsBox();
  ctx("alice.testnet", 1000n, 100n);
  assertThrows(() => savings.deposit(1000n), "Unlock time must be in the future");
  assertThrows(() => savings.deposit(999n), "Unlock time must be in the future");
  assertEq(savings.balanceOf("alice.testnet"), 0n);
  assertEq(savings.totalLocked(), 0n);
  assertEq(savings.deposit(1001n), 100n);

  ctx("bob.testnet", 1000n, 0n);
  assertThrows(() => savings.deposit(9000n), "Deposit required");
  assertEq(savings.unlockTimeOf("bob.testnet"), 0n);
}

export function testHiddenExtendingLockDelaysWithdrawal(): void {
  const savings = new SavingsBox();
  ctx("alice.testnet", 1000n, 100n);
  savings.deposit(2000n);
  ctx("alice.testnet", 1500n, 10n);
  assertEq(savings.deposit(8000n), 110n);
  assertEq(savings.unlockTimeOf("alice.testnet"), 8000n);

  ctx("alice.testnet", 2000n);
  assertEq(savings.isUnlocked("alice.testnet"), false);
  assertThrows(() => savings.withdraw(), "Still locked");
  ctx("alice.testnet", 7999n);
  assertThrows(() => savings.withdraw(), "Still locked");
  ctx("alice.testnet", 8000n);
  assertEq(savings.isUnlocked("alice.testnet"), true);
  assertEq(savings.withdraw(), 110n);
}

export function testHiddenTopUpOfExpiredBoxKeepsRules(): void {
  const savings = new SavingsBox();
  ctx("alice.testnet", 1000n, 100n);
  savings.deposit(2000n);

  // The box has unlocked. A top-up with the same unlock time is allowed even though that time is in the past.
  ctx("alice.testnet", 3000n, 5n);
  assertThrows(() => savings.deposit(1999n), "Cannot shorten lock");
  assertEq(savings.deposit(2000n), 105n);
  ctx("alice.testnet", 3000n);
  assertEq(savings.isUnlocked("alice.testnet"), true);

  // Re-locking an unlocked box is the saver's choice.
  ctx("alice.testnet", 3000n, 5n);
  assertEq(savings.deposit(9000n), 110n);
  ctx("alice.testnet", 3001n);
  assertThrows(() => savings.withdraw(), "Still locked");
  assertEq(savings.totalLocked(), 110n);
}

export function testHiddenBoxesAreIsolated(): void {
  const savings = new SavingsBox();
  ctx("alice.testnet", 1000n, 100n);
  savings.deposit(2000n);
  ctx("bob.testnet", 1000n, 300n);
  savings.deposit(9000n);
  assertEq(savings.totalLocked(), 400n);

  ctx("bob.testnet", 2500n);
  assertThrows(() => savings.withdraw(), "Still locked");
  ctx("carol.testnet", 2500n);
  assertThrows(() => savings.withdraw(), "Nothing to withdraw");
  assertEq(savings.isUnlocked("carol.testnet"), false);
  ctx("alice.testnet", 2500n);
  assertEq(savings.withdraw(), 100n);

  assertEq(savings.balanceOf("bob.testnet"), 300n);
  assertEq(savings.unlockTimeOf("bob.testnet"), 9000n);
  assertEq(savings.totalLocked(), 300n);
}

export function testHiddenFreshBoxAfterWithdrawal(): void {
  const savings = new SavingsBox();
  ctx("alice.testnet", 1000n, 100n);
  savings.deposit(5000n);
  ctx("alice.testnet", 6000n);
  assertEq(savings.withdraw(), 100n);
  assertEq(savings.unlockTimeOf("alice.testnet"), 0n);
  assertEq(savings.isUnlocked("alice.testnet"), false);

  // The old unlock time (5000) no longer applies, but a new box again needs a future time.
  ctx("alice.testnet", 6000n, 40n);
  assertThrows(() => savings.deposit(5500n), "Unlock time must be in the future");
  assertEq(savings.deposit(6500n), 40n);
  ctx("alice.testnet", 6499n);
  assertThrows(() => savings.withdraw(), "Still locked");
  ctx("alice.testnet", 6500n);
  assertEq(savings.withdraw(), 40n);
  assertEq(savings.totalLocked(), 0n);
}
