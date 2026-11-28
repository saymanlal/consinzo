import { LookupMap, near, assert } from "near-sdk-js";

export class SimpleToken {
  private balances = new LookupMap<bigint>("bal:");
  private supply = 0n;

  constructor(initialSupply: bigint) {
    // TODO: require initialSupply > 0n ("Invalid supply") and credit the whole supply to the deployer
  }

  transfer(receiver: string, amount: bigint): void {
    // TODO: run the four checks in the documented order, then debit the caller and credit the receiver
    throw new Error("Not implemented");
  }

  burn(amount: bigint): void {
    // TODO: check amount and balance, then reduce the caller's balance and the total supply
    throw new Error("Not implemented");
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  totalSupply(): bigint {
    return this.supply;
  }
}
