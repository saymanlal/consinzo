import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { SimpleToken } from "../../src/SimpleToken";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenExactErrorsAndOrder(): void {
  ctx("issuer.testnet");
  const token = new SimpleToken(100n);
  assertThrows(() => token.transfer("", 10n), "Invalid receiver");
  assertThrows(() => token.transfer("issuer.testnet", 10n), "Cannot transfer to self");
  assertThrows(() => token.transfer("alice.testnet", 0n), "Amount must be positive");
  assertThrows(() => token.transfer("alice.testnet", -5n), "Amount must be positive");
  // Earlier checks win when several conditions fail at once.
  assertThrows(() => token.transfer("", 0n), "Invalid receiver");
  assertThrows(() => token.transfer("issuer.testnet", 0n), "Cannot transfer to self");
  assertThrows(() => token.transfer("alice.testnet", 0n), "Amount must be positive");
  ctx("alice.testnet");
  assertThrows(() => token.transfer("bob.testnet", 0n), "Amount must be positive");
  assertThrows(() => token.transfer("alice.testnet", 5n), "Cannot transfer to self");
  assertEq(token.balanceOf("issuer.testnet"), 100n);
  assertEq(token.balanceOf("alice.testnet"), 0n);
}

export function testHiddenNegativeAmountCannotMintOrSteal(): void {
  ctx("issuer.testnet");
  const token = new SimpleToken(100n);
  token.transfer("alice.testnet", 50n);
  ctx("mallory.testnet");
  assertThrows(() => token.transfer("alice.testnet", -50n), "Amount must be positive");
  assertThrows(() => token.burn(-50n), "Amount must be positive");
  assertEq(token.balanceOf("mallory.testnet"), 0n);
  assertEq(token.balanceOf("alice.testnet"), 50n);
  assertEq(token.totalSupply(), 100n);
}

export function testHiddenFullBalanceTransferAndConservation(): void {
  ctx("issuer.testnet");
  const token = new SimpleToken(1000n);
  token.transfer("alice.testnet", 1000n);
  assertEq(token.balanceOf("issuer.testnet"), 0n);
  assertThrows(() => token.transfer("alice.testnet", 1n), "Insufficient balance");

  ctx("alice.testnet");
  token.transfer("bob.testnet", 400n);
  token.transfer("carol.testnet", 1n);
  ctx("bob.testnet");
  token.transfer("carol.testnet", 399n);
  token.transfer("issuer.testnet", 1n);

  const sum =
    token.balanceOf("issuer.testnet") +
    token.balanceOf("alice.testnet") +
    token.balanceOf("bob.testnet") +
    token.balanceOf("carol.testnet");
  assertEq(sum, 1000n);
  assertEq(token.totalSupply(), 1000n);
  assertEq(token.balanceOf("alice.testnet"), 599n);
  assertEq(token.balanceOf("bob.testnet"), 0n);
  assertEq(token.balanceOf("carol.testnet"), 400n);
}

export function testHiddenBurnRules(): void {
  ctx("issuer.testnet");
  const token = new SimpleToken(100n);
  token.transfer("alice.testnet", 30n);
  ctx("alice.testnet");
  assertThrows(() => token.burn(0n), "Amount must be positive");
  assertThrows(() => token.burn(31n), "Insufficient balance");
  token.burn(30n);
  assertEq(token.balanceOf("alice.testnet"), 0n);
  assertEq(token.totalSupply(), 70n);
  assertEq(token.balanceOf("issuer.testnet"), 70n);
  assertThrows(() => token.burn(1n), "Insufficient balance");
}

export function testHiddenConstructorAndLargeSupply(): void {
  ctx("issuer.testnet");
  assertThrows(() => new SimpleToken(0n), "Invalid supply");
  assertThrows(() => new SimpleToken(-1n), "Invalid supply");
  const big = 10n ** 33n;
  const token = new SimpleToken(big);
  token.transfer("alice.testnet", big - 1n);
  assertEq(token.balanceOf("issuer.testnet"), 1n);
  assertEq(token.balanceOf("alice.testnet"), big - 1n);
  assertEq(token.totalSupply(), big);
}
