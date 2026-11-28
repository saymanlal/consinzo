import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { AllowanceToken } from "../src/AllowanceToken";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testApproveSetsAllowance(): void {
  ctx("owner.testnet");
  const token = new AllowanceToken(1000n);
  token.approve("spender.testnet", 250n);
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 250n);
  assertEq(token.allowance("spender.testnet", "owner.testnet"), 0n);
  assertEq(token.balanceOf("owner.testnet"), 1000n);
}

export function testTransferFromSpendsAllowance(): void {
  ctx("owner.testnet");
  const token = new AllowanceToken(1000n);
  token.approve("spender.testnet", 250n);

  ctx("spender.testnet");
  token.transferFrom("owner.testnet", "carol.testnet", 100n);
  assertEq(token.balanceOf("owner.testnet"), 900n);
  assertEq(token.balanceOf("carol.testnet"), 100n);
  assertEq(token.balanceOf("spender.testnet"), 0n);
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 150n);
  assertEq(token.totalSupply(), 1000n);
}

export function testTransferFromBeyondAllowanceFails(): void {
  ctx("owner.testnet");
  const token = new AllowanceToken(1000n);
  token.approve("spender.testnet", 50n);
  ctx("spender.testnet");
  assertThrows(() => token.transferFrom("owner.testnet", "spender.testnet", 51n), "Insufficient allowance");
  assertEq(token.balanceOf("owner.testnet"), 1000n);
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 50n);
}

export function testTransferFromWithoutApprovalFails(): void {
  ctx("owner.testnet");
  const token = new AllowanceToken(1000n);
  ctx("mallory.testnet");
  assertThrows(() => token.transferFrom("owner.testnet", "mallory.testnet", 1n), "Insufficient allowance");
}
