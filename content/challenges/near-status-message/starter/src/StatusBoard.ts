import { LookupMap, near, assert } from "near-sdk-js";

export class StatusBoard {
  private readonly maxLength: number;
  private statuses = new LookupMap<string>("status:");
  private counts = new LookupMap<number>("count:");
  private total = 0;

  constructor(maxLength = 64) {
    // TODO: require an integer maxLength >= 1 ("Invalid max length")
    this.maxLength = maxLength;
  }

  setStatus(message: string): number {
    // TODO: reject empty ("Empty status") and over-long ("Status too long") messages, store the status for the caller, bump both counters, return the caller's counter
    throw new Error("Not implemented");
  }

  getStatus(account: string): string | null {
    return this.statuses.get(account);
  }

  clearStatus(): void {
    // TODO: remove the caller's status or throw "No status"; do not touch the counters
    throw new Error("Not implemented");
  }

  updateCount(account: string): number {
    return this.counts.get(account) ?? 0;
  }

  totalUpdates(): number {
    return this.total;
  }

  getMaxLength(): number {
    return this.maxLength;
  }
}
