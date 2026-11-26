import { near, assertEq, assertThrows } from "near-sdk-js";
import { SignerVault } from "../src/SignerVault";

export function testDirectDepositAndWithdraw(): void {
  near._setContext({ predecessorAccountId: "owner.testnet", signerAccountId: "owner.testnet" });
  const vault = new SignerVault();

  near._setContext({
    predecessorAccountId: "alice.testnet",
    signerAccountId: "alice.testnet",
    attachedDeposit: 1000n,
  });
  vault.deposit();
  assertEq(vault.balanceOf("alice.testnet"), 1000n);

  near._setContext({ attachedDeposit: 0n });
  assertEq(vault.withdraw(400n), 400n);
  assertEq(vault.balanceOf("alice.testnet"), 600n);
}

export function testBlocksMaliciousRelayUsingVictimSigner(): void {
  near._setContext({ predecessorAccountId: "owner.testnet", signerAccountId: "owner.testnet" });
  const vault = new SignerVault();

  near._setContext({
    predecessorAccountId: "alice.testnet",
    signerAccountId: "alice.testnet",
    attachedDeposit: 1000n,
  });
  vault.deposit();

  // Malicious proxy contract calls vault while signerAccountId remains alice.testnet
  near._setContext({
    predecessorAccountId: "malicious-relay.testnet",
    signerAccountId: "alice.testnet",
    attachedDeposit: 0n,
  });
  assertThrows(() => vault.withdraw(1000n));
  assertEq(vault.balanceOf("alice.testnet"), 1000n);
}
