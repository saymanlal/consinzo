import { LookupMap, near, assert } from "near-sdk-js";

export interface Grant {
  grantor: string;
  beneficiary: string;
  total: bigint;
  released: bigint;
  startNs: bigint;
  cliffNs: bigint;
  durationNs: bigint;
  revocable: boolean;
  revoked: boolean;
}

export class VestingVault {
  private grants = new LookupMap<Grant>("g:");
  private balances = new LookupMap<bigint>("b:");
  private nextId = 1;

  createGrant(
    beneficiary: string,
    startNs: bigint,
    cliffNs: bigint,
    durationNs: bigint,
    revocable: boolean
  ): number {
    const grantor = near.predecessorAccountId();
    const total = near.attachedDeposit();
    assert(
      total > 0n &&
        beneficiary.length > 0 &&
        beneficiary !== grantor &&
        durationNs > 0n &&
        cliffNs >= 0n &&
        cliffNs <= durationNs,
      "Invalid grant"
    );
    const id = this.nextId++;
    this.grants.set(String(id), {
      grantor,
      beneficiary,
      total,
      released: 0n,
      startNs,
      cliffNs,
      durationNs,
      revocable,
      revoked: false,
    });
    return id;
  }

  vestedAmount(id: number): bigint {
    return this.vested(this.mustGet(id));
  }

  releasable(id: number): bigint {
    const g = this.mustGet(id);
    return this.vested(g) - g.released;
  }

  release(id: number): bigint {
    const g = this.mustGet(id);
    assert(near.predecessorAccountId() === g.beneficiary, "Not beneficiary");
    const amount = this.vested(g) - g.released;
    assert(amount > 0n, "Nothing to release");
    // Record the release before crediting so the grant can never pay the same tokens twice.
    this.grants.set(String(id), { ...g, released: g.released + amount });
    this.credit(g.beneficiary, amount);
    return amount;
  }

  revoke(id: number): bigint {
    const g = this.mustGet(id);
    assert(near.predecessorAccountId() === g.grantor, "Not grantor");
    assert(g.revocable, "Not revocable");
    assert(!g.revoked, "Already revoked");
    const vested = this.vested(g);
    const refund = g.total - vested;
    // Shrinking total to the vested amount freezes the schedule: vested() returns
    // total for a revoked grant, and released <= vested still holds.
    this.grants.set(String(id), { ...g, total: vested, revoked: true });
    if (refund > 0n) this.credit(g.grantor, refund);
    return refund;
  }

  getGrant(id: number): Grant | null {
    return this.grants.get(String(id));
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  private mustGet(id: number): Grant {
    const g = this.grants.get(String(id));
    assert(g !== null, "Grant not found");
    return g as Grant;
  }

  private vested(g: Grant): bigint {
    if (g.revoked) return g.total;
    const now = near.blockTimestamp();
    if (now < g.startNs + g.cliffNs) return 0n;
    if (now >= g.startNs + g.durationNs) return g.total;
    return (g.total * (now - g.startNs)) / g.durationNs;
  }

  private credit(account: string, amount: bigint): void {
    this.balances.set(account, (this.balances.get(account) ?? 0n) + amount);
  }
}
