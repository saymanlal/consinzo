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
    // TODO: throw "Only admin" unless the caller is the admin
  }

  setPauser(account: string): void {
    // TODO: admin only; store the pauser ("" removes it)
    throw new Error("Not implemented");
  }

  transferAdmin(newAdmin: string): void {
    // TODO: admin only; reject an empty account ("Invalid admin"); replace the admin
    throw new Error("Not implemented");
  }

  pause(): void {
    // TODO: allow the admin or the current pauser ("Not authorized"), reject when already paused ("Already paused"), set the flag
    throw new Error("Not implemented");
  }

  unpause(): void {
    // TODO: admin only; reject when not paused ("Not paused"); clear the flag
    throw new Error("Not implemented");
  }

  deposit(): bigint {
    // TODO: reject while paused ("Contract is paused"), require a positive attached deposit ("Deposit required"), credit the caller and return the new balance
    throw new Error("Not implemented");
  }

  withdraw(amount: bigint): bigint {
    // TODO: validate amount ("Amount must be positive") and balance ("Insufficient balance"), debit the caller and return the remaining balance; must work while paused
    throw new Error("Not implemented");
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
