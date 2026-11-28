import { LookupMap, near, assert } from "near-sdk-js";

export const MAX_FEE_BPS = 1000n;
const BPS = 10000n;

export class FeeRouter {
  private owner: string;
  private feeRecipient: string;
  private feeBps: bigint;
  private balances = new LookupMap<bigint>("b:");

  constructor(feeRecipient: string, feeBps: bigint) {
    assert(feeRecipient.length > 0 && feeBps >= 0n && feeBps <= MAX_FEE_BPS, "Invalid fee config");
    this.owner = near.predecessorAccountId();
    this.feeRecipient = feeRecipient;
    this.feeBps = feeBps;
  }

  pay(merchant: string): bigint {
    const amount = near.attachedDeposit();
    assert(amount > 0n, "Zero payment");
    assert(merchant.length > 0, "Invalid merchant");
    const fee = (amount * this.feeBps) / BPS;
    this.credit(this.feeRecipient, fee);
    this.credit(merchant, amount - fee);
    return fee;
  }

  setFeeConfig(recipient: string, feeBps: bigint): void {
    // Authorise the immediate caller. signerAccountId() would let any contract the
    // owner interacts with reconfigure the router on the owner's behalf.
    assert(near.predecessorAccountId() === this.owner, "Not owner");
    // Bound the values so that even a compromised or mistaken owner cannot
    // confiscate payments or burn fees into the empty account.
    assert(
      recipient.length > 0 && feeBps >= 0n && feeBps <= MAX_FEE_BPS,
      "Invalid fee config"
    );
    this.feeRecipient = recipient;
    this.feeBps = feeBps;
  }

  transferOwnership(newOwner: string): void {
    assert(near.predecessorAccountId() === this.owner, "Not owner");
    assert(newOwner.length > 0, "Invalid owner");
    this.owner = newOwner;
  }

  withdraw(): bigint {
    const caller = near.predecessorAccountId();
    const amount = this.balances.get(caller) ?? 0n;
    assert(amount > 0n, "Nothing to withdraw");
    this.balances.set(caller, 0n);
    return amount;
  }

  getOwner(): string {
    return this.owner;
  }

  getFeeRecipient(): string {
    return this.feeRecipient;
  }

  getFeeBps(): bigint {
    return this.feeBps;
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  private credit(account: string, amount: bigint): void {
    this.balances.set(account, (this.balances.get(account) ?? 0n) + amount);
  }
}
