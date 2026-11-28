import { near, assertEq, assertThrows } from "near-sdk-js";
import { FeeRouter, MAX_FEE_BPS } from "../../src/FeeRouter";

function caller(who: string, deposit: bigint = 0n): void {
  near._setContext({ predecessorAccountId: who, signerAccountId: who, attachedDeposit: deposit });
}

function setup(): FeeRouter {
  caller("owner.testnet");
  return new FeeRouter("treasury.testnet", 250n);
}

export function testHiddenFeeBoundAppliesToOwner(): void {
  const router = setup();
  caller("owner.testnet");
  assertThrows(() => router.setFeeConfig("treasury.testnet", MAX_FEE_BPS + 1n), "Invalid fee config");
  assertThrows(() => router.setFeeConfig("treasury.testnet", 10001n), "Invalid fee config");
  assertThrows(() => router.setFeeConfig("treasury.testnet", -1n), "Invalid fee config");
  assertThrows(() => router.setFeeConfig("", 100n), "Invalid fee config");
  assertEq(router.getFeeBps(), 250n);
  assertEq(router.getFeeRecipient(), "treasury.testnet");

  router.setFeeConfig("treasury.testnet", MAX_FEE_BPS);
  assertEq(router.getFeeBps(), 1000n);
  router.setFeeConfig("treasury.testnet", 0n);
  caller("customer.testnet", 777n);
  assertEq(router.pay("shop.testnet"), 0n);
  assertEq(router.balanceOf("shop.testnet"), 777n);
}

export function testHiddenIntermediaryContractCannotUseOwnersSignature(): void {
  const router = setup();
  // The owner signed a transaction to a malicious contract, which now calls the router.
  near._setContext({
    signerAccountId: "owner.testnet",
    predecessorAccountId: "evil-contract.testnet",
    attachedDeposit: 0n,
  });
  assertThrows(() => router.setFeeConfig("evil-contract.testnet", 1000n), "Not owner");
  assertThrows(() => router.transferOwnership("evil-contract.testnet"), "Not owner");
  assertEq(router.getFeeRecipient(), "treasury.testnet");
  assertEq(router.getOwner(), "owner.testnet");
}

export function testHiddenOwnershipTransferMovesPrivilege(): void {
  const router = setup();
  caller("owner.testnet");
  router.transferOwnership("dao.testnet");
  assertEq(router.getOwner(), "dao.testnet");

  assertThrows(() => router.setFeeConfig("owner.testnet", 500n), "Not owner");
  caller("dao.testnet");
  router.setFeeConfig("dao-treasury.testnet", 500n);
  assertEq(router.getFeeRecipient(), "dao-treasury.testnet");

  caller("attacker.testnet");
  assertThrows(() => router.transferOwnership("attacker.testnet"), "Not owner");
  assertThrows(() => router.setFeeConfig("attacker.testnet", 0n), "Not owner");
  assertEq(router.getOwner(), "dao.testnet");
}

export function testHiddenAccruedFeesStayWithPreviousRecipient(): void {
  const router = setup();
  caller("customer.testnet", 8000n);
  router.pay("shop.testnet");
  assertEq(router.balanceOf("treasury.testnet"), 200n);

  caller("owner.testnet");
  router.setFeeConfig("treasury-v2.testnet", 1000n);
  assertEq(router.balanceOf("treasury.testnet"), 200n);
  assertEq(router.balanceOf("treasury-v2.testnet"), 0n);

  caller("customer.testnet", 8000n);
  assertEq(router.pay("shop.testnet"), 800n);
  assertEq(router.balanceOf("treasury-v2.testnet"), 800n);
  assertEq(router.balanceOf("shop.testnet"), 7800n + 7200n);

  caller("treasury.testnet");
  assertEq(router.withdraw(), 200n);
  caller("attacker.testnet");
  assertThrows(() => router.withdraw(), "Nothing to withdraw");

  // Every unit paid in is owed to exactly one party.
  const owed =
    router.balanceOf("treasury.testnet") +
    router.balanceOf("treasury-v2.testnet") +
    router.balanceOf("shop.testnet");
  assertEq(owed, 16000n - 200n);
}
