import { LookupMap, near, assert } from "near-sdk-js";

export type EscrowStatus = "OPEN" | "RELEASED" | "REFUNDED";

export interface EscrowRecord {
  depositor: string;
  beneficiary: string;
  amount: bigint;
  releaseAfterNs: bigint;
  status: EscrowStatus;
}

export class TimelockEscrow {
  private escrows = new LookupMap<EscrowRecord>("esc:");
  private releasedBalances = new LookupMap<bigint>("rel:");
  private refundedBalances = new LookupMap<bigint>("ref:");

  createEscrow(id: string, beneficiary: string, releaseAfterNs: bigint): void {
    const caller = near.predecessorAccountId();
    const deposit = near.attachedDeposit();
    assert(id.length > 0 && beneficiary.length > 0, "Invalid escrow arguments");
    assert(beneficiary !== caller, "Depositor cannot be beneficiary");
    assert(deposit > 0n, "Attached deposit must be strictly positive");
    assert(!this.escrows.containsKey(id), "Escrow ID already exists");

    this.escrows.set(id, {
      depositor: caller,
      beneficiary,
      amount: deposit,
      releaseAfterNs,
      status: "OPEN",
    });
  }

  release(id: string): bigint {
    const rec = this.escrows.get(id);
    assert(rec !== null, "Escrow not found");
    const escrow = rec as EscrowRecord;
    assert(escrow.status === "OPEN", "Escrow already settled");

    const caller = near.predecessorAccountId();
    const isDepositor = caller === escrow.depositor;
    const isBeneficiary = caller === escrow.beneficiary;
    assert(isDepositor || isBeneficiary, "Unauthorized caller");
    if (isBeneficiary && !isDepositor) {
      assert(near.blockTimestamp() >= escrow.releaseAfterNs, "Timelock has not expired");
    }

    this.escrows.set(id, { ...escrow, status: "RELEASED" });
    const prev = this.releasedBalances.get(escrow.beneficiary) ?? 0n;
    this.releasedBalances.set(escrow.beneficiary, prev + escrow.amount);
    return escrow.amount;
  }

  refund(id: string): bigint {
    const rec = this.escrows.get(id);
    assert(rec !== null, "Escrow not found");
    const escrow = rec as EscrowRecord;
    assert(escrow.status === "OPEN", "Escrow already settled");

    const caller = near.predecessorAccountId();
    const isDepositor = caller === escrow.depositor;
    const isBeneficiary = caller === escrow.beneficiary;
    assert(isDepositor || isBeneficiary, "Unauthorized caller");
    if (isDepositor) {
      assert(near.blockTimestamp() < escrow.releaseAfterNs, "Escrow timelock already matured");
    }

    this.escrows.set(id, { ...escrow, status: "REFUNDED" });
    const prev = this.refundedBalances.get(escrow.depositor) ?? 0n;
    this.refundedBalances.set(escrow.depositor, prev + escrow.amount);
    return escrow.amount;
  }

  getEscrow(id: string): EscrowRecord | null {
    return this.escrows.get(id);
  }

  getReleasedBalance(account: string): bigint {
    return this.releasedBalances.get(account) ?? 0n;
  }

  getRefundedBalance(account: string): bigint {
    return this.refundedBalances.get(account) ?? 0n;
  }
}
