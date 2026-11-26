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
    assert(id.length > 0 && beneficiary.length > 0, "Invalid escrow arguments");
    // TODO: validate deposit > 0n, caller !== beneficiary, uniqueness, and store EscrowRecord
  }

  release(id: string): bigint {
    // TODO: validate OPEN status, caller/timelock rules, mark RELEASED, credit beneficiary
    return 0n;
  }

  refund(id: string): bigint {
    // TODO: validate OPEN status, caller/timelock rules, mark REFUNDED, credit depositor
    return 0n;
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
