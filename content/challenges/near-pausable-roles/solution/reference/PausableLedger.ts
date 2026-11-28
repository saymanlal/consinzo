import { LookupMap, near, assert } from "near-sdk-js";

export class PausableLedger {
  private admin: string;
  private pauser = "";
  private paused = false;
  private balances = new LookupMap<bigint>("bal:");

  constructor() {
    this.admin = near.predecessorAccountId();
  }

  private requireAdmin(): void {
    assert(near.predecessorAccountId() === this.admin, "Only admin");
  }

  setPauser(account: string): void {
    this.requireAdmin();
    this.pauser = account;
  }

  transferAdmin(newAdmin: string): void {
    this.requireAdmin();
    assert(newAdmin.length > 0, "Invalid admin");
    this.admin = newAdmin;
  }

  pause(): void {
    const caller = near.predecessorAccountId();
    // An unset pauser ("") can never equal a real predecessor, but the explicit length test documents the intent.
    const isPauser = this.pauser.length > 0 && caller === this.pauser;
    assert(caller === this.admin || isPauser, "Not authorized");
    assert(!this.paused, "Already paused");
    this.paused = true;
  }

  unpause(): void {
    this.requireAdmin();
    assert(this.paused, "Not paused");
    this.paused = false;
  }

  deposit(): bigint {
    assert(!this.paused, "Contract is paused");
    const amount = near.attachedDeposit();
    assert(amount > 0n, "Deposit required");
    const caller = near.predecessorAccountId();
    const updated = this.balanceOf(caller) + amount;
    this.balances.set(caller, updated);
    return updated;
  }

  withdraw(amount: bigint): bigint {
    // Deliberately no pause check: an emergency stop must not trap user funds.
    assert(amount > 0n, "Amount must be positive");
    const caller = near.predecessorAccountId();
    const balance = this.balanceOf(caller);
    assert(balance >= amount, "Insufficient balance");
    const remaining = balance - amount;
    this.balances.set(caller, remaining);
    return remaining;
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  isPaused(): boolean {
    return this.paused;
  }

  getAdmin(): string {
    return this.admin;
  }

  getPauser(): string {
    return this.pauser;
  }
}
