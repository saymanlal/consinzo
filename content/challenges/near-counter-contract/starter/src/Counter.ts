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
    // TODO: validate 1 <= by <= maxStep, update value & lastCaller, return value
    return this.value;
  }

  decrement(by = 1): number {
    // TODO: validate step & guard underflow, update value & lastCaller, return value
    return this.value;
  }

  reset(): void {
    // TODO: enforce owner-only reset via near.predecessorAccountId()
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
