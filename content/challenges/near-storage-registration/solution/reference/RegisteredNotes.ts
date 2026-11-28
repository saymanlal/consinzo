import { LookupMap, near, assert } from "near-sdk-js";

export const MAX_NOTE_LENGTH = 200;

export class RegisteredNotes {
  private owner: string;
  private storageFee: bigint;
  // Fee recorded per registered account. A key in this map means "registered".
  private storagePaid = new LookupMap<bigint>("paid:");
  private refundable = new LookupMap<bigint>("refund:");
  private notes = new LookupMap<string>("note:");
  private held = 0n;

  constructor(storageFee: bigint) {
    assert(storageFee > 0n, "Invalid fee");
    this.owner = near.predecessorAccountId();
    this.storageFee = storageFee;
  }

  private credit(account: string, amount: bigint): void {
    if (amount > 0n) this.refundable.set(account, this.refundableOf(account) + amount);
  }

  register(): void {
    const caller = near.predecessorAccountId();
    assert(!this.storagePaid.containsKey(caller), "Already registered");
    const deposit = near.attachedDeposit();
    const fee = this.storageFee;
    assert(deposit >= fee, "Insufficient storage deposit");

    // Record the fee charged now: later fee changes must not alter what this account gets back.
    this.storagePaid.set(caller, fee);
    this.held += fee;
    this.credit(caller, deposit - fee);
  }

  unregister(): bigint {
    const caller = near.predecessorAccountId();
    const paid = this.storagePaid.get(caller);
    if (paid === null) throw new Error("Not registered");

    // Release the storage the fee was paying for before handing the fee back.
    this.notes.remove(caller);
    this.storagePaid.remove(caller);
    this.held -= paid;
    this.credit(caller, paid);
    return paid;
  }

  setNote(text: string): void {
    const caller = near.predecessorAccountId();
    assert(this.storagePaid.containsKey(caller), "Not registered");
    assert(text.length >= 1 && text.length <= MAX_NOTE_LENGTH, "Invalid note");
    this.notes.set(caller, text);
  }

  getNote(account: string): string | null {
    return this.notes.get(account);
  }

  claimRefund(): bigint {
    const caller = near.predecessorAccountId();
    const amount = this.refundableOf(caller);
    assert(amount > 0n, "Nothing to refund");
    this.refundable.remove(caller);
    return amount;
  }

  setStorageFee(newFee: bigint): void {
    assert(near.predecessorAccountId() === this.owner, "Only owner");
    assert(newFee > 0n, "Invalid fee");
    this.storageFee = newFee;
  }

  isRegistered(account: string): boolean {
    return this.storagePaid.containsKey(account);
  }

  storageBalanceOf(account: string): bigint {
    return this.storagePaid.get(account) ?? 0n;
  }

  refundableOf(account: string): bigint {
    return this.refundable.get(account) ?? 0n;
  }

  getStorageFee(): bigint {
    return this.storageFee;
  }

  totalStorageHeld(): bigint {
    return this.held;
  }
}
