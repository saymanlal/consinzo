import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { StatusBoard } from "../../src/StatusBoard";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenRejectedUpdateChangesNothing(): void {
  const board = new StatusBoard(8);
  ctx("alice.testnet");
  board.setStatus("ok");
  assertThrows(() => board.setStatus("way too long"), "Status too long");
  assertThrows(() => board.setStatus(""), "Empty status");
  assertEq(board.getStatus("alice.testnet"), "ok");
  assertEq(board.updateCount("alice.testnet"), 1);
  assertEq(board.totalUpdates(), 1);
}

export function testHiddenCounterContinuesAfterClear(): void {
  const board = new StatusBoard();
  ctx("alice.testnet");
  board.setStatus("a");
  board.setStatus("b");
  board.clearStatus();
  assertEq(board.totalUpdates(), 2);
  assertEq(board.setStatus("c"), 3);
  assertEq(board.getStatus("alice.testnet"), "c");
  assertEq(board.totalUpdates(), 3);
}

export function testHiddenSameTextStillCounts(): void {
  const board = new StatusBoard();
  ctx("alice.testnet");
  assertEq(board.setStatus("same"), 1);
  assertEq(board.setStatus("same"), 2);
  assertEq(board.updateCount("alice.testnet"), 2);
}

export function testHiddenConfiguredLimits(): void {
  ctx("alice.testnet");
  assertThrows(() => new StatusBoard(0), "Invalid max length");
  assertThrows(() => new StatusBoard(-3), "Invalid max length");
  assertThrows(() => new StatusBoard(2.5), "Invalid max length");

  const tiny = new StatusBoard(1);
  assertEq(tiny.getMaxLength(), 1);
  assertEq(tiny.setStatus("x"), 1);
  assertThrows(() => tiny.setStatus("xy"), "Status too long");

  const standard = new StatusBoard();
  assertEq(standard.getMaxLength(), 64);
  assertEq(standard.setStatus("s".repeat(64)), 1);
  assertThrows(() => standard.setStatus("s".repeat(65)), "Status too long");

  const wide = new StatusBoard(200);
  assertEq(wide.setStatus("w".repeat(200)), 1);
}

export function testHiddenClearAffectsOnlyCaller(): void {
  const board = new StatusBoard();
  ctx("alice.testnet");
  board.setStatus("alice here");
  ctx("bob.testnet");
  assertThrows(() => board.clearStatus(), "No status");
  board.setStatus("bob here");
  board.clearStatus();
  assertEq(board.getStatus("alice.testnet"), "alice here");
  assertEq(board.getStatus("bob.testnet"), null);
  assertEq(board.updateCount("bob.testnet"), 1);
  assertEq(board.updateCount("alice.testnet"), 1);
  assertEq(board.totalUpdates(), 2);
}
