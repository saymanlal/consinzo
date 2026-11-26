import { near, assertEq, assertThrows } from "near-sdk-js";
import { Counter } from "../../src/Counter";

export function testHiddenOwnerOnlyResetAndPredecessorCheck(): void {
  near._setContext({
    predecessorAccountId: "owner.testnet",
    signerAccountId: "owner.testnet",
  });
  const counter = new Counter(10);
  counter.increment(7);

  // Attacker shares signerAccountId (e.g. malicious cross-contract relay)
  near._setContext({
    predecessorAccountId: "malicious.testnet",
    signerAccountId: "owner.testnet",
  });
  assertThrows(() => counter.reset(), "Unauthorized");

  near._setContext({ predecessorAccountId: "owner.testnet" });
  counter.reset();
  assertEq(counter.getValue(), 0);
  assertEq(counter.getLastCaller(), "owner.testnet");
}

export function testHiddenUnderflowAndNonPositiveStepsRejected(): void {
  near._setContext({ predecessorAccountId: "owner.testnet" });
  const counter = new Counter(5);
  counter.increment(2);
  assertThrows(() => counter.decrement(3), "Underflow");
  assertThrows(() => counter.increment(0));
  assertThrows(() => counter.increment(-1));
  assertThrows(() => counter.decrement(0));
  assertEq(counter.getValue(), 2);
}
