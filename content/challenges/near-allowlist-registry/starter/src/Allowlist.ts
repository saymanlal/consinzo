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
    // TODO: throw "Only owner" unless the caller is the owner
  }

  add(account: string): void {
    // TODO: owner only; reject an empty account ("Invalid account") and a duplicate ("Already listed"); add the account and update the count
    throw new Error("Not implemented");
  }

  remove(account: string): void {
    // TODO: owner only; reject an account that is not listed ("Not listed"); remove it and update the count
    throw new Error("Not implemented");
  }

  isAllowed(account: string): boolean {
    return this.allowed.containsKey(account);
  }

  allowedCount(): number {
    return this.count;
  }

  checkIn(): number {
    // TODO: require the caller to be allowlisted ("Not allowlisted"), increment and return its check-in count
    throw new Error("Not implemented");
  }

  checkInsOf(account: string): number {
    return this.checkIns.get(account) ?? 0;
  }

  getOwner(): string {
    return this.owner;
  }
}
