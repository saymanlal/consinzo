import { near, assertEq, assertThrows } from "near-sdk-js";
import { FeeRouter } from "../src/FeeRouter";

function caller(who: string, deposit: bigint = 0n): void {
  near._setContext({ predecessorAccountId: who, signerAccountId: who, attachedDeposit: deposit });
}

function setup(): FeeRouter {
  caller("owner.testnet");
  return new FeeRouter("treasury.testnet", 250n);
}

export function testFeeSplit(): void {
  const router = setup();
  caller("customer.testnet", 10000n);
  assertEq(router.pay("shop.testnet"), 250n);
  assertEq(router.balanceOf("treasury.testnet"), 250n);
  assertEq(router.balanceOf("shop.testnet"), 9750n);
}

export function testExploitAttackerCannotRedirectFees(): void {
  const router = setup();

  caller("attacker.testnet");
  assertThrows(() => router.setFeeConfig("attacker.testnet", 250n), "Not owner");
  assertEq(router.getFeeRecipient(), "treasury.testnet");

  caller("customer.testnet", 10000n);
  router.pay("shop.testnet");
  assertEq(router.balanceOf("attacker.testnet"), 0n);
  assertEq(router.balanceOf("treasury.testnet"), 250n);
}

export function testExploitAttackerCannotRaiseFee(): void {
  const router = setup();
  caller("attacker.testnet");
  assertThrows(() => router.setFeeConfig("attacker.testnet", 10000n));
  assertEq(router.getFeeBps(), 250n);

  caller("customer.testnet", 4000n);
  router.pay("shop.testnet");
  assertEq(router.balanceOf("shop.testnet"), 3900n);
}

export function testOwnerCanReconfigure(): void {
  const router = setup();
  caller("owner.testnet");
  router.setFeeConfig("new-treasury.testnet", 100n);
  assertEq(router.getFeeRecipient(), "new-treasury.testnet");
  assertEq(router.getFeeBps(), 100n);

  caller("customer.testnet", 10000n);
  assertEq(router.pay("shop.testnet"), 100n);
  assertEq(router.balanceOf("new-treasury.testnet"), 100n);
}
