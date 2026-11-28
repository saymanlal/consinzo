import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { SimpleToken } from "../src/SimpleToken";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testInitialSupplyGoesToDeployer(): void {
  ctx("issuer.testnet");
  const token = new SimpleToken(1000n);
  assertEq(token.totalSupply(), 1000n);
  assertEq(token.balanceOf("issuer.testnet"), 1000n);
  assertEq(token.balanceOf("alice.testnet"), 0n);
}

export function testTransferMovesBalance(): void {
  ctx("issuer.testnet");
  const token = new SimpleToken(1000n);
  token.transfer("alice.testnet", 300n);
  assertEq(token.balanceOf("issuer.testnet"), 700n);
  assertEq(token.balanceOf("alice.testnet"), 300n);
  assertEq(token.totalSupply(), 1000n);
}

export function testTransferMoreThanBalanceFails(): void {
  ctx("issuer.testnet");
  const token = new SimpleToken(100n);
  assertThrows(() => token.transfer("alice.testnet", 101n), "Insufficient balance");
  ctx("alice.testnet");
  assertThrows(() => token.transfer("bob.testnet", 1n), "Insufficient balance");
  assertEq(token.balanceOf("issuer.testnet"), 100n);
}

export function testBurnReducesSupply(): void {
  ctx("issuer.testnet");
  const token = new SimpleToken(100n);
  token.burn(40n);
  assertEq(token.balanceOf("issuer.testnet"), 60n);
  assertEq(token.totalSupply(), 60n);
}
