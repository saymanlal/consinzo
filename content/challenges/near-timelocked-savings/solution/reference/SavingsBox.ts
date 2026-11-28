import { LookupMap, near, assert } from "near-sdk-js";

export interface Box {
  amount: bigint;
  unlockAt: bigint;
}

export class SavingsBox {
  private boxes = new LookupMap<Box>("box:");
  private total = 0n;

  deposit(unlockAt: bigint): bigint {
    const amount = near.attachedDeposit();
    assert(amount > 0n, "Deposit required");
    const caller = near.predecessorAccountId();
    const existing = this.boxes.get(caller);

    let updated: Box;
    if (existing === null) {
      assert(unlockAt > near.blockTimestamp(), "Unlock time must be in the future");
      updated = { amount, unlockAt };
    } else {
      // A top-up can only keep or extend the lock; otherwise a 1-yocto deposit could unlock the box early.
      assert(unlockAt >= existing.unlockAt, "Cannot shorten lock");
      updated = { amount: existing.amount + amount, unlockAt };
    }
    this.boxes.set(caller, updated);
    this.total += amount;
    return updated.amount;
  }

  withdraw(): bigint {
    const caller = near.predecessorAccountId();
    const box = this.boxes.get(caller);
    if (box === null) throw new Error("Nothing to withdraw");
    assert(near.blockTimestamp() >= box.unlockAt, "Still locked");
    // Delete before reporting the payout so a second call finds nothing.
    this.boxes.remove(caller);
    this.total -= box.amount;
    return box.amount;
  }

  balanceOf(account: string): bigint {
    return this.boxes.get(account)?.amount ?? 0n;
  }

  unlockTimeOf(account: string): bigint {
    return this.boxes.get(account)?.unlockAt ?? 0n;
  }

  isUnlocked(account: string): boolean {
    const box = this.boxes.get(account);
    return box !== null && near.blockTimestamp() >= box.unlockAt;
  }

  totalLocked(): bigint {
    return this.total;
  }
}
