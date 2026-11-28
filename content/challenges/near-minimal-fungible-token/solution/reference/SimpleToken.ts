import { LookupMap, near, assert } from "near-sdk-js";

export class SimpleToken {
  private balances = new LookupMap<bigint>("bal:");
  private supply = 0n;

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

    // Debit and credit the same amount: the sum of balances is unchanged.
    this.balances.set(sender, senderBalance - amount);
    this.balances.set(receiver, this.balanceOf(receiver) + amount);
  }

  burn(amount: bigint): void {
    const caller = near.predecessorAccountId();
    assert(amount > 0n, "Amount must be positive");
    const balance = this.balanceOf(caller);
    assert(balance >= amount, "Insufficient balance");
    this.balances.set(caller, balance - amount);
    this.supply -= amount;
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  totalSupply(): bigint {
    return this.supply;
  }
}
