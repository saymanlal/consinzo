import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { Guestbook } from "../../src/Guestbook";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenLengthBoundaries(): void {
  const book = new Guestbook();
  ctx("alice.testnet");
  assertEq(book.addMessage("x"), 0);
  assertEq(book.addMessage("y".repeat(280)), 1);
  assertThrows(() => book.addMessage("z".repeat(281)), "Invalid message length");
  // A rejected message must not consume an index.
  assertEq(book.totalMessages(), 2);
  assertEq(book.addMessage("after"), 2);
  assertEq(book.getMessage(1)?.text.length, 280);
}

export function testHiddenLatestTruncatesAndHandlesEmpty(): void {
  const book = new Guestbook();
  ctx("alice.testnet");
  assertEq(book.latest(5).length, 0);
  book.addMessage("a");
  ctx("bob.testnet", 2000n);
  book.addMessage("b");

  const all = book.latest(10);
  assertEq(all.length, 2);
  assertEq(all[0]?.text, "b");
  assertEq(all[0]?.sender, "bob.testnet");
  assertEq(all[0]?.timestamp, 2000n);
  assertEq(all[1]?.index, 0);
  assertEq(book.latest(0).length, 0);
  assertEq(book.latest(1)[0]?.index, 1);
}

export function testHiddenInvalidCounts(): void {
  const book = new Guestbook();
  ctx("alice.testnet");
  book.addMessage("a");
  assertThrows(() => book.latest(-1), "Invalid count");
  assertThrows(() => book.latest(1.5), "Invalid count");
  assertEq(book.latest(1).length, 1);
}

export function testHiddenManyMessagesKeepOrder(): void {
  const book = new Guestbook();
  for (let i = 0; i < 12; i++) {
    ctx(i % 2 === 0 ? "alice.testnet" : "bob.testnet", BigInt(100 + i));
    assertEq(book.addMessage("m" + i), i);
  }
  const last = book.latest(3);
  assertEq(last.map((m) => m.text).join(","), "m11,m10,m9");
  assertEq(last[1]?.sender, "alice.testnet");
  assertEq(last[2]?.timestamp, 109n);
  assertEq(book.totalMessages(), 12);
}
