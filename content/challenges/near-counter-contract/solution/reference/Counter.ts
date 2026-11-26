import { near, assert } from "near-sdk-js";

export class Counter {
  private value = 0;
  private owner: string;
  private lastCaller = "";
  private readonly maxStep: number;

  constructor(maxStep = 10) {
    assert(Number.isInteger(maxStep) && maxStep >= 1, "maxStep must be positive integer");
    this.maxStep = maxStep;
    this.owner = near.predecessorAccountId();
  }

  increment(by = 1): number {
    assert(Number.isInteger(by) && by >= 1 && by <= this.maxStep, "Step exceeds maxStep or is non-positive");
    this.value += by;
    this.lastCaller = near.predecessorAccountId();
    return this.value;
  }

  decrement(by = 1): number {
    assert(Number.isInteger(by) && by >= 1 && by <= this.maxStep, "Step exceeds maxStep or is non-positive");
    assert(this.value >= by, "Underflow: counter cannot drop below zero");
    this.value -= by;
    this.lastCaller = near.predecessorAccountId();
    return this.value;
  }

  reset(): void {
    const caller = near.predecessorAccountId();
    assert(caller === this.owner, "Unauthorized: only owner can reset");
    this.value = 0;
    this.lastCaller = caller;
  }

  getValue(): number {
    return this.value;
  }

  getOwner(): string {
    return this.owner;
  }

  getLastCaller(): string {
    return this.lastCaller;
  }
}
