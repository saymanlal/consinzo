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
    assert(
      near.predecessorAccountId() === near.currentAccountId(),
      "Callback restricted to self"
    );
    const rec = this.pending.get(String(txId));
    assert(rec !== null, "Unknown txId");
    const tx = rec as PendingTransfer;
    assert(tx.status === "PENDING", "Transfer already finalized");

    if (succeeded) {
      this.pending.set(String(txId), { ...tx, status: "SETTLED" });
      return;
    }

    this.pending.set(String(txId), { ...tx, status: "REFUNDED" });
    const prev = this.balances.get(tx.account) ?? 0n;
    this.balances.set(tx.account, prev + tx.amount);
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  getTransfer(txId: number): PendingTransfer | null {
    return this.pending.get(String(txId));
  }
}
