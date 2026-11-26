import { near, assertEq, assertThrows } from "near-sdk-js";
import { TimelockEscrow } from "../src/Escrow";

export function testCreateAndBeneficiaryReleaseAfterTimelock(): void {
  const escrow = new TimelockEscrow();
  near._setContext({
    predecessorAccountId: "alice.testnet",
    attachedDeposit: 500n,
    blockTimestamp: 1000n,
  });
  escrow.createEscrow("deal-1", "bob.testnet", 2000n);

  near._setContext({ predecessorAccountId: "bob.testnet", blockTimestamp: 1500n, attachedDeposit: 0n });
  assertThrows(() => escrow.release("deal-1"), "Timelock");

  near._setContext({ predecessorAccountId: "bob.testnet", blockTimestamp: 2000n });
  const released = escrow.release("deal-1");
  assertEq(released, 500n);
  assertEq(escrow.getReleasedBalance("bob.testnet"), 500n);
  assertEq(escrow.getEscrow("deal-1")?.status, "RELEASED");
}

export function testEarlyDepositorRefund(): void {
  const escrow = new TimelockEscrow();
  near._setContext({
    predecessorAccountId: "alice.testnet",
    attachedDeposit: 300n,
    blockTimestamp: 1000n,
  });
  escrow.createEscrow("deal-2", "bob.testnet", 5000n);
  near._setContext({ predecessorAccountId: "alice.testnet", blockTimestamp: 1200n, attachedDeposit: 0n });
  const refunded = escrow.refund("deal-2");
  assertEq(refunded, 300n);
  assertEq(escrow.getRefundedBalance("alice.testnet"), 300n);
}
