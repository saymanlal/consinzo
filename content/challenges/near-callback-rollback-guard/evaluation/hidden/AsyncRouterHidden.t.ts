import { near, assertEq, assertThrows } from "near-sdk-js";
import { AsyncRouter } from "../../src/AsyncRouter";

export function testHiddenDuplicateRefundAndSettledReplayBlocked(): void {
  const router = new AsyncRouter();
  near._setContext({
    currentAccountId: "router.testnet",
    predecessorAccountId: "alice.testnet",
    attachedDeposit: 1000n,
  });
  router.deposit();

  near._setContext({ attachedDeposit: 0n });
  const tx1 = router.initiateWithdraw(400n);
  const tx2 = router.initiateWithdraw(400n);

  near._setContext({ predecessorAccountId: "router.testnet" });
  router.onTransferCallback(tx1, true);
  assertEq(router.getTransfer(tx1)?.status, "SETTLED");
  assertThrows(() => router.onTransferCallback(tx1, false));

  router.onTransferCallback(tx2, false);
  assertEq(router.balanceOf("alice.testnet"), 600n);
  assertThrows(() => router.onTransferCallback(tx2, false));
  assertEq(router.balanceOf("alice.testnet"), 600n);
}
