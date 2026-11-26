import { near, assertEq, assertThrows } from "near-sdk-js";
import { AsyncRouter } from "../src/AsyncRouter";

export function testFailedPromiseRefundsOnceViaSelfCallback(): void {
  const router = new AsyncRouter();
  near._setContext({
    currentAccountId: "router.testnet",
    predecessorAccountId: "alice.testnet",
    attachedDeposit: 500n,
  });
  router.deposit();

  near._setContext({ attachedDeposit: 0n });
  const txId = router.initiateWithdraw(300n);
  assertEq(router.balanceOf("alice.testnet"), 200n);

  // External attacker cannot invoke callback
  near._setContext({ predecessorAccountId: "attacker.testnet" });
  assertThrows(() => router.onTransferCallback(txId, false));

  // Self-callback refunds once cleanly
  near._setContext({ predecessorAccountId: "router.testnet" });
  router.onTransferCallback(txId, false);
  assertEq(router.balanceOf("alice.testnet"), 500n);
  assertEq(router.getTransfer(txId)?.status, "REFUNDED");
}
