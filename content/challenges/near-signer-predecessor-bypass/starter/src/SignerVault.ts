import { LookupMap, near, assert } from "near-sdk-js";

export class SignerVault {
  private readonly owner: string;
  private paused = false;
  private balances = new LookupMap<bigint>("bal:");

  constructor() {
    this.owner = near.predecessorAccountId();
  }

  setPaused(nextPaused: boolean): void {
    // BUG: uses signerAccountId() instead of predecessorAccountId()
    assert(near.signerAccountId() === this.owner, "Unauthorized");
    this.paused = nextPaused;
  }

  deposit(): void {
    const amount = near.attachedDeposit();
    assert(amount > 0n, "Zero deposit");
    // BUG: attributes deposit to signerAccountId() instead of predecessorAccountId()
    const user = near.signerAccountId();
    const prev = this.balances.get(user) ?? 0n;
    this.balances.set(user, prev + amount);
  }

  withdraw(amount: bigint): bigint {
    assert(!this.paused, "Vault paused");
    assert(amount > 0n, "Invalid withdrawal amount");
    // BUG: checks signerAccountId() enabling cross-contract confused-deputy drain
    const user = near.signerAccountId();
    const bal = this.balances.get(user) ?? 0n;
    assert(bal >= amount, "Insufficient balance");
    this.balances.set(user, bal - amount);
    return amount;
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  isPaused(): boolean {
    return this.paused;
  }
}
