import { near, assertEq, assertThrows } from "near-sdk-js";
import { SignerVault } from "../../src/SignerVault";

export function testHiddenRelayCannotPauseOrCreditWrongAccount(): void {
  near._setContext({ predecessorAccountId: "owner.testnet", signerAccountId: "owner.testnet" });
  const vault = new SignerVault();

  // Relay signed by owner must not be allowed to pause
  near._setContext({
    predecessorAccountId: "evil-relay.testnet",
    signerAccountId: "owner.testnet",
    attachedDeposit: 500n,
  });
  assertThrows(() => vault.setPaused(true), "Unauthorized");
  assertEq(vault.isPaused(), false);

  // Deposit through relay credits the immediate predecessor, not signer
  vault.deposit();
  assertEq(vault.balanceOf("evil-relay.testnet"), 500n);
  assertEq(vault.balanceOf("owner.testnet"), 0n);

  // Real owner can pause and block withdrawals
  near._setContext({ predecessorAccountId: "owner.testnet", signerAccountId: "owner.testnet", attachedDeposit: 0n });
  vault.setPaused(true);
  near._setContext({ predecessorAccountId: "evil-relay.testnet" });
  assertThrows(() => vault.withdraw(100n), "paused");
}
