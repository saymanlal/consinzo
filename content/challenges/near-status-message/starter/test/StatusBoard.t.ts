import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { StatusBoard } from "../src/StatusBoard";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testSetStatusStoresMessageAndCounts(): void {
  const board = new StatusBoard();
  ctx("alice.testnet");
  assertEq(board.setStatus("gm"), 1);
  assertEq(board.setStatus("building"), 2);
  ctx("bob.testnet");
  assertEq(board.setStatus("hello"), 1);

  assertEq(board.getStatus("alice.testnet"), "building");
  assertEq(board.getStatus("bob.testnet"), "hello");
  assertEq(board.getStatus("carol.testnet"), null);
  assertEq(board.updateCount("alice.testnet"), 2);
  assertEq(board.totalUpdates(), 3);
}

export function testLengthLimitEnforced(): void {
  const board = new StatusBoard(5);
  ctx("alice.testnet");
  assertThrows(() => board.setStatus("123456"), "Status too long");
  assertThrows(() => board.setStatus(""), "Empty status");
  assertEq(board.setStatus("12345"), 1);
  assertEq(board.getStatus("alice.testnet"), "12345");
}

export function testClearStatusKeepsCounter(): void {
  const board = new StatusBoard();
  ctx("alice.testnet");
  board.setStatus("one");
  board.clearStatus();
  assertEq(board.getStatus("alice.testnet"), null);
  assertEq(board.updateCount("alice.testnet"), 1);
  assertThrows(() => board.clearStatus(), "No status");
}
