import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { Poll } from "../src/Poll";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testVotesAreTallied(): void {
  const poll = new Poll(["red", "green", "blue"]);
  ctx("alice.testnet");
  poll.vote(1);
  ctx("bob.testnet");
  poll.vote(1);
  ctx("carol.testnet");
  poll.vote(2);

  assertEq(poll.tally(0), 0);
  assertEq(poll.tally(1), 2);
  assertEq(poll.tally(2), 1);
  assertEq(poll.totalVotes(), 3);
  assertEq(poll.leading(), 1);
  assertEq(poll.optionLabel(1), "green");
}

export function testAccountCannotVoteTwice(): void {
  const poll = new Poll(["yes", "no"]);
  ctx("alice.testnet");
  poll.vote(1);
  assertThrows(() => poll.vote(0), "Already voted");
  assertEq(poll.tally(0), 0);
  assertEq(poll.tally(1), 1);
  assertEq(poll.choiceOf("alice.testnet"), 1);
  assertEq(poll.hasVoted("alice.testnet"), true);
  assertEq(poll.hasVoted("bob.testnet"), false);
}

export function testInvalidOptionRejected(): void {
  const poll = new Poll(["yes", "no"]);
  ctx("alice.testnet");
  assertThrows(() => poll.vote(2), "Invalid option");
  assertEq(poll.totalVotes(), 0);
  assertEq(poll.hasVoted("alice.testnet"), false);
}
