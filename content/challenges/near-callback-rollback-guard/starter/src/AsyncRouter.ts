import { LookupMap, near, assert } from "near-sdk-js";

export type TransferStatus = "PENDING" | "SETTLED" | "REFUNDED";

export interface PendingTransfer {
  account: string;
  amount: bigint;
  status: TransferStatus;
}

export class AsyncRouter {
  private balances = new LookupMap<bigint>("b:");
  private pending = new LookupMap<PendingTransfer>("p:");
  private nextTxId = 1;

  deposit(): void {
    const amount = near.attachedDeposit();
    assert(amount > 0n, "Zero deposit");
    const caller = near.predecessorAccountId();
    this.balances.set(caller, (this.balances.get(caller) ?? 0n) + amount);
  }

  initiateWithdraw(amount: bigint): number {
    assert(amount > 0n, "Amount must be positive");
    const caller = near.predecessorAccountId();
    const bal = this.balances.get(caller) ?? 0n;
    assert(bal >= amount, "Insufficient balance");

    this.balances.set(caller, bal - amount);
    const txId = this.nextTxId++;
    this.pending.set(String(txId), {
      account: caller,
      amount,
      status: "PENDING",
    });
    return txId;
  }

  onTransferCallback(txId: number, succeeded: boolean): void {
    // BUG 1: Missing self-callback authorization (predecessor === currentAccountId)
    const rec = this.pending.get(String(txId));
    assert(rec !== null, "Unknown txId");
    const tx = rec as PendingTransfer;

    // BUG 2: Does not check or update tx.status, allowing unlimited duplicate refunds
    if (!succeeded) {
      const prev = this.balances.get(tx.account) ?? 0n;
      this.balances.set(tx.account, prev + tx.amount);
    }
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  getTransfer(txId: number): PendingTransfer | null {
    return this.pending.get(String(txId));
  }
}
