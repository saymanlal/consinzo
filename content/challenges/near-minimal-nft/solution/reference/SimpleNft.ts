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
    assert(near.predecessorAccountId() === this.minter, "Only minter");
    assert(tokenId.length > 0, "Invalid token id");
    assert(receiver.length > 0, "Invalid receiver");
    assert(!this.owners.containsKey(tokenId), "Token already exists");

    this.owners.set(tokenId, receiver);
    this.balances.set(receiver, this.balanceOf(receiver) + 1);
    this.supply += 1;
  }

  transfer(tokenId: string, receiver: string): void {
    const owner = this.owners.get(tokenId);
    if (owner === null) throw new Error("Token not found");
    // Authorisation is per token: only its current owner may move it.
    assert(near.predecessorAccountId() === owner, "Not token owner");
    assert(receiver.length > 0, "Invalid receiver");
    assert(receiver !== owner, "Cannot transfer to self");

    this.owners.set(tokenId, receiver);
    this.balances.set(owner, this.balanceOf(owner) - 1);
    this.balances.set(receiver, this.balanceOf(receiver) + 1);
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
