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
    // TODO: owner check ("Only owner"), key check ("Invalid key"), reject unchanged values ("No change"), store the value and append a ConfigChange, return its index
    throw new Error("Not implemented");
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
    // TODO: owner check ("Only owner"), reject an empty account ("Invalid owner"), replace the owner
    throw new Error("Not implemented");
  }

  getOwner(): string {
    return this.owner;
  }
}
