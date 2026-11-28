import { LookupMap, near, assert } from "near-sdk-js";

export interface Box {
  amount: bigint;
  unlockAt: bigint;
}

export class SavingsBox {
  private boxes = new LookupMap<Box>("box:");
  private total = 0n;

  deposit(unlockAt: bigint): bigint {
    // TODO: require a positive deposit ("Deposit required"); create a box with a future unlock time ("Unlock time must be in the future") or top up an existing one without shortening it ("Cannot shorten lock"); return the box balance
    throw new Error("Not implemented");
  }

  withdraw(): bigint {
    // TODO: require a box ("Nothing to withdraw") whose unlock time has been reached ("Still locked"); delete it, reduce the total and return the amount
    throw new Error("Not implemented");
  }

  balanceOf(account: string): bigint {
    return this.boxes.get(account)?.amount ?? 0n;
  }

  unlockTimeOf(account: string): bigint {
    return this.boxes.get(account)?.unlockAt ?? 0n;
  }

  isUnlocked(account: string): boolean {
    // TODO: true only when the account has a box and the block timestamp is at or past its unlock time
    return false;
  }

  totalLocked(): bigint {
    return this.total;
  }
}
