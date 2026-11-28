import { LookupMap, near, assert } from "near-sdk-js";

export interface ConfigChange {
  key: string;
  oldValue: string | null;
  newValue: string;
  changedBy: string;
  timestamp: bigint;
}

export class OwnerConfig {
  private owner: string;
  private values = new LookupMap<string>("cfg:");
  private log = new LookupMap<ConfigChange>("log:");
  private logLength = 0;

  constructor() {
    this.owner = near.predecessorAccountId();
  }

  setValue(key: string, value: string): number {
    const caller = near.predecessorAccountId();
    assert(caller === this.owner, "Only owner");
    assert(key.length > 0, "Invalid key");
    // get() returns null for a missing key, so an empty string is still a real, distinct value.
    const oldValue = this.values.get(key);
    assert(oldValue !== value, "No change");

    this.values.set(key, value);
    const index = this.logLength;
    this.log.set(String(index), {
      key,
      oldValue,
      newValue: value,
      changedBy: caller,
      timestamp: near.blockTimestamp(),
    });
    this.logLength = index + 1;
    return index;
  }

  getValue(key: string): string | null {
    return this.values.get(key);
  }

  changeCount(): number {
    return this.logLength;
  }

  getChange(index: number): ConfigChange | null {
    return this.log.get(String(index));
  }

  transferOwnership(newOwner: string): void {
    assert(near.predecessorAccountId() === this.owner, "Only owner");
    assert(newOwner.length > 0, "Invalid owner");
    this.owner = newOwner;
  }

  getOwner(): string {
    return this.owner;
  }
}
