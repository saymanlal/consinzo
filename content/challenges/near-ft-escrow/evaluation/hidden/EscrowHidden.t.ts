import { near, assertEq, assertThrows } from "near-sdk-js";
import { TimelockEscrow } from "../../src/Escrow";

export function testHiddenDoubleClaimAndUnauthorizedAccessBlocked(): void {
  const escrow = new TimelockEscrow();
  near._setContext({
    predecessorAccountId: "alice.testnet",
    attachedDeposit: 900n,
    blockTimestamp: 100n,
  });
  escrow.createEscrow("deal-x", "bob.testnet", 500n);

  near._setContext({ predecessorAccountId: "eve.testnet", blockTimestamp: 999n, attachedDeposit: 0n });
  assertThrows(() => escrow.release("deal-x"), "Unauthorized");
  assertThrows(() => escrow.refund("deal-x"), "Unauthorized");

  // Depositor can approve early release
  near._setContext({ predecessorAccountId: "alice.testnet", blockTimestamp: 150n });
  assertEq(escrow.release("deal-x"), 900n);

  // Double release or refund after release must fail
  assertThrows(() => escrow.release("deal-x"), "settled");
  assertThrows(() => escrow.refund("deal-x"), "settled");
  assertEq(escrow.getReleasedBalance("bob.testnet"), 900n);
}

export function testHiddenZeroDepositSelfEscrowAndExpiredRefundBlocked(): void {
  const escrow = new TimelockEscrow();
  near._setContext({
    predecessorAccountId: "alice.testnet",
    attachedDeposit: 0n,
    blockTimestamp: 100n,
  });
  assertThrows(() => escrow.createEscrow("z", "bob.testnet", 200n));

  near._setContext({ attachedDeposit: 100n });
  assertThrows(() => escrow.createEscrow("self", "alice.testnet", 200n));

  escrow.createEscrow("matured", "bob.testnet", 500n);
  near._setContext({ predecessorAccountId: "alice.testnet", blockTimestamp: 500n, attachedDeposit: 0n });
  assertThrows(() => escrow.refund("matured"));
}
