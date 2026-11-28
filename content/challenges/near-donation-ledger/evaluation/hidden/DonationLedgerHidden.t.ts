import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { DonationLedger } from "../../src/DonationLedger";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenLeaderUsesCumulativeTotals(): void {
  const ledger = new DonationLedger();
  ctx("alice.testnet", 1n, 60n);
  ledger.donate();
  ctx("bob.testnet", 2n, 100n);
  ledger.donate();
  assertEq(ledger.topDonor(), "bob.testnet");

  // Alice's single donation (50) is smaller than Bob's, but her total (110) is larger.
  ctx("alice.testnet", 3n, 50n);
  assertEq(ledger.donate(), 110n);
  assertEq(ledger.topDonor(), "alice.testnet");
  assertEq(ledger.topDonation(), 110n);
  assertEq(ledger.donorCount(), 2);
  assertEq(ledger.totalDonated(), 210n);
}

export function testHiddenTieKeepsCurrentLeader(): void {
  const ledger = new DonationLedger();
  ctx("alice.testnet", 1n, 100n);
  ledger.donate();
  ctx("bob.testnet", 2n, 100n);
  ledger.donate();
  assertEq(ledger.topDonor(), "alice.testnet");
  assertEq(ledger.topDonation(), 100n);

  ctx("bob.testnet", 3n, 1n);
  ledger.donate();
  assertEq(ledger.topDonor(), "bob.testnet");
  assertEq(ledger.topDonation(), 101n);

  // Alice equals Bob again: Bob stays in front.
  ctx("alice.testnet", 4n, 1n);
  ledger.donate();
  assertEq(ledger.topDonor(), "bob.testnet");
}

export function testHiddenFailedDonationChangesNothing(): void {
  const ledger = new DonationLedger();
  ctx("alice.testnet", 1n, 5n);
  ledger.donate();
  ctx("bob.testnet", 2n, 0n);
  assertThrows(() => ledger.donate(), "Deposit required");
  assertEq(ledger.donorCount(), 1);
  assertEq(ledger.donationOf("bob.testnet"), 0n);
  assertEq(ledger.topDonor(), "alice.testnet");
  assertEq(ledger.totalDonated(), 5n);
}

export function testHiddenLargeAmountsStayExact(): void {
  const ledger = new DonationLedger();
  const oneNear = 1000000000000000000000000n;
  ctx("whale.testnet", 1n, oneNear * 1000000n);
  ledger.donate();
  ctx("whale.testnet", 2n, 1n);
  assertEq(ledger.donate(), oneNear * 1000000n + 1n);
  assertEq(ledger.totalDonated(), oneNear * 1000000n + 1n);
  assertEq(ledger.donorCount(), 1);
}
