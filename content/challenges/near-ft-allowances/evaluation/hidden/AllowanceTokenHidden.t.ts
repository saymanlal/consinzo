import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { AllowanceToken } from "../../src/AllowanceToken";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenApproveOverwritesAndRevokes(): void {
  ctx("owner.testnet");
  const token = new AllowanceToken(1000n);
  token.approve("spender.testnet", 100n);
  token.approve("spender.testnet", 40n);
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 40n);

  token.approve("spender.testnet", 0n);
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 0n);
  ctx("spender.testnet");
  assertThrows(() => token.transferFrom("owner.testnet", "spender.testnet", 1n), "Insufficient allowance");
}

export function testHiddenAllowancesAreIsolatedPerPair(): void {
  ctx("owner.testnet");
  const token = new AllowanceToken(1000n);
  token.transfer("alice.testnet", 500n);
  token.approve("s1.testnet", 100n);
  token.approve("s2.testnet", 200n);
  ctx("alice.testnet");
  token.approve("s1.testnet", 300n);

  ctx("s1.testnet");
  token.transferFrom("owner.testnet", "bob.testnet", 100n);
  // s1's allowance over owner is used up; its allowance over alice and s2's allowance are untouched.
  assertThrows(() => token.transferFrom("owner.testnet", "bob.testnet", 1n), "Insufficient allowance");
  assertEq(token.allowance("alice.testnet", "s1.testnet"), 300n);
  assertEq(token.allowance("owner.testnet", "s2.testnet"), 200n);
  token.transferFrom("alice.testnet", "bob.testnet", 300n);

  assertEq(token.balanceOf("owner.testnet"), 400n);
  assertEq(token.balanceOf("alice.testnet"), 200n);
  assertEq(token.balanceOf("bob.testnet"), 400n);
  assertEq(token.totalSupply(), 1000n);

  // A spender's allowance cannot be used by the receiver or by the owner of another pair.
  ctx("bob.testnet");
  assertThrows(() => token.transferFrom("owner.testnet", "bob.testnet", 1n), "Insufficient allowance");
}

export function testHiddenCheckOrderAndFailedSpendKeepsAllowance(): void {
  ctx("owner.testnet");
  const token = new AllowanceToken(100n);
  // Approval may exceed the balance.
  token.approve("spender.testnet", 500n);

  ctx("spender.testnet");
  assertThrows(() => token.transferFrom("owner.testnet", "", 10n), "Invalid receiver");
  assertThrows(() => token.transferFrom("owner.testnet", "bob.testnet", 0n), "Amount must be positive");
  assertThrows(() => token.transferFrom("owner.testnet", "bob.testnet", -10n), "Amount must be positive");
  assertThrows(() => token.transferFrom("owner.testnet", "bob.testnet", 501n), "Insufficient allowance");
  assertThrows(() => token.transferFrom("owner.testnet", "bob.testnet", 101n), "Insufficient balance");
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 500n);
  assertEq(token.balanceOf("owner.testnet"), 100n);

  token.transferFrom("owner.testnet", "bob.testnet", 100n);
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 400n);
  assertEq(token.balanceOf("owner.testnet"), 0n);
  assertEq(token.balanceOf("bob.testnet"), 100n);
  assertThrows(() => token.transferFrom("owner.testnet", "bob.testnet", 1n), "Insufficient balance");
}

export function testHiddenApproveValidation(): void {
  ctx("owner.testnet");
  const token = new AllowanceToken(100n);
  assertThrows(() => token.approve("", 10n), "Invalid spender");
  assertThrows(() => token.approve("owner.testnet", 10n), "Invalid spender");
  assertThrows(() => token.approve("spender.testnet", -1n), "Negative allowance");
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 0n);
  assertEq(token.allowance("owner.testnet", "owner.testnet"), 0n);
}

export function testHiddenSpendBackToOwnerAndDirectTransfer(): void {
  ctx("owner.testnet");
  const token = new AllowanceToken(100n);
  token.approve("spender.testnet", 60n);
  // A direct transfer by the owner does not touch the allowance.
  token.transfer("alice.testnet", 30n);
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 60n);

  ctx("spender.testnet");
  token.transferFrom("owner.testnet", "owner.testnet", 20n);
  assertEq(token.balanceOf("owner.testnet"), 70n);
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 40n);
  token.transferFrom("owner.testnet", "spender.testnet", 40n);
  assertEq(token.balanceOf("spender.testnet"), 40n);
  assertEq(token.balanceOf("owner.testnet"), 30n);
  assertEq(token.allowance("owner.testnet", "spender.testnet"), 0n);
  assertEq(token.totalSupply(), 100n);
}
