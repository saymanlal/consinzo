import { LookupMap, near, assert } from "near-sdk-js";

export class Allowlist {
  private owner: string;
  private allowed = new LookupMap<boolean>("allow:");
  private checkIns = new LookupMap<number>("checkin:");
  private count = 0;

  constructor() {
    this.owner = near.predecessorAccountId();
  }

  private requireOwner(): void {
    assert(near.predecessorAccountId() === this.owner, "Only owner");
  }

  add(account: string): void {
    this.requireOwner();
    assert(account.length > 0, "Invalid account");
    assert(!this.allowed.containsKey(account), "Already listed");
    this.allowed.set(account, true);
    this.count += 1;
  }

  remove(account: string): void {
    this.requireOwner();
    assert(this.allowed.containsKey(account), "Not listed");
    // Remove the key instead of storing false, so containsKey stays the single source of truth.
    this.allowed.remove(account);
    this.count -= 1;
  }

  isAllowed(account: string): boolean {
    return this.allowed.containsKey(account);
  }

  allowedCount(): number {
    return this.count;
  }

  checkIn(): number {
    const caller = near.predecessorAccountId();
    assert(this.allowed.containsKey(caller), "Not allowlisted");
    const next = (this.checkIns.get(caller) ?? 0) + 1;
    this.checkIns.set(caller, next);
    return next;
  }

  checkInsOf(account: string): number {
    return this.checkIns.get(account) ?? 0;
  }

  getOwner(): string {
    return this.owner;
  }
}
