import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { SavingsBox } from "../src/SavingsBox";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testDepositLocksFunds(): void {
  const savings = new SavingsBox();
  ctx("alice.testnet", 1000n, 500n);
  assertEq(savings.deposit(5000n), 500n);
  assertEq(savings.balanceOf("alice.testnet"), 500n);
  assertEq(savings.unlockTimeOf("alice.testnet"), 5000n);
  assertEq(savings.totalLocked(), 500n);

  ctx("alice.testnet", 4999n);
  assertThrows(() => savings.withdraw(), "Still locked");
  assertEq(savings.balanceOf("alice.testnet"), 500n);
}

export function testWithdrawAfterUnlock(): void {
  const savings = new SavingsBox();
  ctx("alice.testnet", 1000n, 500n);
  savings.deposit(5000n);
  ctx("alice.testnet", 5000n);
  assertEq(savings.withdraw(), 500n);
  assertEq(savings.balanceOf("alice.testnet"), 0n);
  assertEq(savings.totalLocked(), 0n);
  assertThrows(() => savings.withdraw(), "Nothing to withdraw");
}

export function testTopUpAddsToBox(): void {
  const savings = new SavingsBox();
  ctx("alice.testnet", 1000n, 100n);
  savings.deposit(5000n);
  ctx("alice.testnet", 2000n, 50n);
  assertEq(savings.deposit(5000n), 150n);
  assertEq(savings.unlockTimeOf("alice.testnet"), 5000n);
}

export function testCannotShortenLock(): void {
  const savings = new SavingsBox();
  ctx("alice.testnet", 1000n, 100n);
  savings.deposit(5000n);
  ctx("alice.testnet", 2000n, 1n);
  assertThrows(() => savings.deposit(3000n), "Cannot shorten lock");
  assertEq(savings.unlockTimeOf("alice.testnet"), 5000n);
  assertEq(savings.balanceOf("alice.testnet"), 100n);
}
