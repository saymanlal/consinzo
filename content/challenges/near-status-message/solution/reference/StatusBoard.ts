import { LookupMap, near, assert } from "near-sdk-js";

export class StatusBoard {
  private readonly maxLength: number;
  private statuses = new LookupMap<string>("status:");
  private counts = new LookupMap<number>("count:");
  private total = 0;

  constructor(maxLength = 64) {
    assert(Number.isInteger(maxLength) && maxLength >= 1, "Invalid max length");
    this.maxLength = maxLength;
  }

  setStatus(message: string): number {
    assert(message.length > 0, "Empty status");
    assert(message.length <= this.maxLength, "Status too long");
    const caller = near.predecessorAccountId();
    this.statuses.set(caller, message);
    const next = (this.counts.get(caller) ?? 0) + 1;
    this.counts.set(caller, next);
    this.total += 1;
    return next;
  }

  getStatus(account: string): string | null {
    return this.statuses.get(account);
  }

  clearStatus(): void {
    const caller = near.predecessorAccountId();
    assert(this.statuses.containsKey(caller), "No status");
    // Only the message is removed; the update counter is history and stays.
    this.statuses.remove(caller);
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
