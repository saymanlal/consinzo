import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { Poll } from "../../src/Poll";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenVoterOfOptionZeroCannotVoteAgain(): void {
  const poll = new Poll(["a", "b"]);
  ctx("alice.testnet");
  poll.vote(0);
  assertEq(poll.hasVoted("alice.testnet"), true);
  assertEq(poll.choiceOf("alice.testnet"), 0);
  assertThrows(() => poll.vote(0), "Already voted");
  assertThrows(() => poll.vote(1), "Already voted");
  assertEq(poll.tally(0), 1);
  assertEq(poll.tally(1), 0);
  assertEq(poll.totalVotes(), 1);
  assertEq(poll.choiceOf("bob.testnet"), null);
}

export function testHiddenInvalidIndices(): void {
  const poll = new Poll(["a", "b", "c"]);
  ctx("alice.testnet");
  assertThrows(() => poll.vote(-1), "Invalid option");
  assertThrows(() => poll.vote(3), "Invalid option");
  assertThrows(() => poll.vote(0.5), "Invalid option");
  assertThrows(() => poll.tally(3), "Invalid option");
  assertThrows(() => poll.optionLabel(-1), "Invalid option");
  // A failed vote does not use up the account's vote.
  poll.vote(2);
  assertEq(poll.tally(2), 1);
}

export function testHiddenConstructorValidation(): void {
  ctx("alice.testnet");
  assertThrows(() => new Poll([]), "Invalid options");
  assertThrows(() => new Poll(["only"]), "Invalid options");
  assertThrows(() => new Poll(["a", ""]), "Invalid options");
  assertThrows(() => new Poll(["a", "b", "a"]), "Invalid options");
  const poll = new Poll(["a", "b"]);
  assertEq(poll.optionCount(), 2);
  assertEq(poll.leading(), -1);
}

export function testHiddenLeadingTieBreaksToLowestIndex(): void {
  const poll = new Poll(["a", "b", "c"]);
  ctx("v1.testnet");
  poll.vote(2);
  assertEq(poll.leading(), 2);
  ctx("v2.testnet");
  poll.vote(1);
  // b and c are tied with one vote each: the lower index wins.
  assertEq(poll.leading(), 1);
  ctx("v3.testnet");
  poll.vote(2);
  assertEq(poll.leading(), 2);
  ctx("v4.testnet");
  poll.vote(0);
  ctx("v5.testnet");
  poll.vote(0);
  assertEq(poll.leading(), 0);
  assertEq(poll.totalVotes(), 5);
}

export function testHiddenOptionsAreCopied(): void {
  const labels = ["a", "b"];
  const poll = new Poll(labels);
  labels.push("c");
  labels[0] = "changed";
  assertEq(poll.optionCount(), 2);
  assertEq(poll.optionLabel(0), "a");
  ctx("alice.testnet");
  assertThrows(() => poll.vote(2), "Invalid option");
}
