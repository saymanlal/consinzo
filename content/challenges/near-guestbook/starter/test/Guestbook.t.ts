import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { Guestbook } from "../src/Guestbook";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testAddMessageRecordsSenderAndTimestamp(): void {
  const book = new Guestbook();
  ctx("alice.testnet", 5000n);
  assertEq(book.addMessage("hello near"), 0);
  ctx("bob.testnet", 6000n);
  assertEq(book.addMessage("second"), 1);

  assertEq(book.totalMessages(), 2);
  const first = book.getMessage(0);
  assert(first !== null, "message 0 must exist");
  assertEq(first?.sender, "alice.testnet");
  assertEq(first?.text, "hello near");
  assertEq(first?.timestamp, 5000n);
  assertEq(first?.index, 0);
  assertEq(book.getMessage(1)?.sender, "bob.testnet");
  assertEq(book.getMessage(2), null);
}

export function testLatestReturnsNewestFirst(): void {
  const book = new Guestbook();
  ctx("alice.testnet");
  book.addMessage("one");
  book.addMessage("two");
  book.addMessage("three");

  const two = book.latest(2);
  assertEq(two.length, 2);
  assertEq(two[0]?.text, "three");
  assertEq(two[1]?.text, "two");
}

export function testRejectsEmptyMessage(): void {
  const book = new Guestbook();
  ctx("alice.testnet");
  assertThrows(() => book.addMessage(""), "Invalid message length");
  assertEq(book.totalMessages(), 0);
}
