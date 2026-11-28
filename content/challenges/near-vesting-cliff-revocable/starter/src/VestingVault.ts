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
    // TODO: validate the arguments and the attached deposit, store the grant, return its id
    return 0;
  }

  vestedAmount(id: number): bigint {
    // TODO: zero before the cliff, linear until startNs + durationNs, frozen once revoked
    return 0n;
  }

  releasable(id: number): bigint {
    // TODO: vested minus already released
    return 0n;
  }

  release(id: number): bigint {
    // TODO: beneficiary only; pay out the releasable amount to the internal ledger
    return 0n;
  }

  revoke(id: number): bigint {
    // TODO: grantor only; freeze the grant at the vested amount and refund the rest
    return 0n;
  }

  getGrant(id: number): Grant | null {
    return this.grants.get(String(id));
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }
}
