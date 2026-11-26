import { near, assertEq, assertThrows } from "near-sdk-js";
import { Counter } from "../src/Counter";

export function testIncrementAndAttribution(): void {
  near._setContext({ predecessorAccountId: "owner.testnet" });
  const counter = new Counter(5);
  near._setContext({ predecessorAccountId: "alice.testnet" });
  assertEq(counter.increment(3), 3);
  assertEq(counter.getValue(), 3);
  assertEq(counter.getLastCaller(), "alice.testnet");
}

export function testDecrementWithinBounds(): void {
  near._setContext({ predecessorAccountId: "owner.testnet" });
  const counter = new Counter(5);
  counter.increment(4);
  assertEq(counter.decrement(2), 2);
  assertEq(counter.getValue(), 2);
}

export function testRejectStepAboveMax(): void {
  near._setContext({ predecessorAccountId: "owner.testnet" });
  const counter = new Counter(5);
  assertThrows(() => counter.increment(6), "maxStep");
}
