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
    // TODO: reject a registered caller ("Already registered") and a deposit below the fee ("Insufficient storage deposit"); record the current fee as storage balance, credit any excess as refundable
    throw new Error("Not implemented");
  }

  unregister(): bigint {
    // TODO: require registration ("Not registered"); delete the caller's note and registration, move the recorded fee to the refundable balance and return it
    throw new Error("Not implemented");
  }

  setNote(text: string): void {
    // TODO: require registration ("Not registered") and a 1..MAX_NOTE_LENGTH text ("Invalid note"); store the note
    throw new Error("Not implemented");
  }

  getNote(account: string): string | null {
    return this.notes.get(account);
  }

  claimRefund(): bigint {
    // TODO: pay out and zero the caller's refundable balance, or throw "Nothing to refund"
    throw new Error("Not implemented");
  }

  setStorageFee(newFee: bigint): void {
    // TODO: owner only ("Only owner"), newFee > 0n ("Invalid fee"); change the fee for future registrations
    throw new Error("Not implemented");
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
