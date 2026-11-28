import { LookupMap, near, assert } from "near-sdk-js";

export class SimpleNft {
  private minter: string;
  private owners = new LookupMap<string>("owner:");
  private balances = new LookupMap<number>("bal:");
  private supply = 0;

  constructor() {
    this.minter = near.predecessorAccountId();
  }

  mint(tokenId: string, receiver: string): void {
    // TODO: run the four mint checks in the documented order, record the owner, update the receiver balance and the supply
    throw new Error("Not implemented");
  }

  transfer(tokenId: string, receiver: string): void {
    // TODO: run the four transfer checks in the documented order, then move the token and adjust both balances
    throw new Error("Not implemented");
  }

  ownerOf(tokenId: string): string | null {
    return this.owners.get(tokenId);
  }

  balanceOf(account: string): number {
    return this.balances.get(account) ?? 0;
  }

  totalSupply(): number {
    return this.supply;
  }

  getMinter(): string {
    return this.minter;
  }
}
