import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { DonationLedger } from "../src/DonationLedger";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testDonationsAccumulatePerAccount(): void {
  const ledger = new DonationLedger();
  ctx("alice.testnet", 1000n, 50n);
  assertEq(ledger.donate(), 50n);
  ctx("alice.testnet", 1001n, 25n);
  assertEq(ledger.donate(), 75n);
  ctx("bob.testnet", 1002n, 10n);
  assertEq(ledger.donate(), 10n);

  assertEq(ledger.donationOf("alice.testnet"), 75n);
  assertEq(ledger.donationOf("bob.testnet"), 10n);
  assertEq(ledger.donationOf("carol.testnet"), 0n);
  assertEq(ledger.totalDonated(), 85n);
  assertEq(ledger.donorCount(), 2);
}

export function testTopDonorTracksLargestTotal(): void {
  const ledger = new DonationLedger();
  assertEq(ledger.topDonor(), "");
  assertEq(ledger.topDonation(), 0n);

  ctx("alice.testnet", 1000n, 100n);
  ledger.donate();
  ctx("bob.testnet", 1000n, 300n);
  ledger.donate();
  assertEq(ledger.topDonor(), "bob.testnet");
  assertEq(ledger.topDonation(), 300n);
}

export function testZeroDepositRejected(): void {
  const ledger = new DonationLedger();
  ctx("alice.testnet", 1000n, 0n);
  assertThrows(() => ledger.donate(), "Deposit required");
  assertEq(ledger.donorCount(), 0);
  assertEq(ledger.totalDonated(), 0n);
}
