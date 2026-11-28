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
    // TODO: validate spender ("Invalid spender") and amount ("Negative allowance"), then set (not add) the caller's allowance for spender
    throw new Error("Not implemented");
  }

  allowance(owner: string, spender: string): bigint {
    // TODO: return the remaining allowance of spender over owner's tokens
    return 0n;
  }

  transferFrom(owner: string, receiver: string, amount: bigint): void {
    // TODO: the caller is the spender; run the four checks in order, then reduce the allowance and move the tokens
    throw new Error("Not implemented");
  }
}
