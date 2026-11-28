import { LookupMap, near, assert } from "near-sdk-js";

export class AllowanceToken {
  private balances = new LookupMap<bigint>("bal:");
  private allowances = new LookupMap<bigint>("allow:");
  private supply: bigint;

  constructor(initialSupply: bigint) {
    assert(initialSupply > 0n, "Invalid supply");
    this.supply = initialSupply;
    this.balances.set(near.predecessorAccountId(), initialSupply);
  }

  transfer(receiver: string, amount: bigint): void {
    const sender = near.predecessorAccountId();
    assert(receiver.length > 0, "Invalid receiver");
    assert(receiver !== sender, "Cannot transfer to self");
    assert(amount > 0n, "Amount must be positive");
    const senderBalance = this.balanceOf(sender);
    assert(senderBalance >= amount, "Insufficient balance");
    this.balances.set(sender, senderBalance - amount);
    this.balances.set(receiver, this.balanceOf(receiver) + amount);
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  totalSupply(): bigint {
    return this.supply;
  }

  private allowanceKey(owner: string, spender: string): string {
    return owner + ":" + spender;
  }

  approve(spender: string, amount: bigint): void {
    const owner = near.predecessorAccountId();
    assert(spender.length > 0 && spender !== owner, "Invalid spender");
    assert(amount >= 0n, "Negative allowance");
    // Overwrite semantics: the caller states the total it is willing to delegate from now on.
    this.allowances.set(this.allowanceKey(owner, spender), amount);
  }

  allowance(owner: string, spender: string): bigint {
    return this.allowances.get(this.allowanceKey(owner, spender)) ?? 0n;
  }

  transferFrom(owner: string, receiver: string, amount: bigint): void {
    const spender = near.predecessorAccountId();
    assert(receiver.length > 0, "Invalid receiver");
    assert(amount > 0n, "Amount must be positive");
    const key = this.allowanceKey(owner, spender);
    const allowed = this.allowances.get(key) ?? 0n;
    assert(allowed >= amount, "Insufficient allowance");
    const ownerBalance = this.balanceOf(owner);
    assert(ownerBalance >= amount, "Insufficient balance");

    this.allowances.set(key, allowed - amount);
    // Write the debit first and re-read for the credit so that receiver === owner nets to zero.
    this.balances.set(owner, ownerBalance - amount);
    this.balances.set(receiver, this.balanceOf(receiver) + amount);
  }
}
