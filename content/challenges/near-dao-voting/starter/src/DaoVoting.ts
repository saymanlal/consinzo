import { LookupMap, near, assert } from "near-sdk-js";

export interface Proposal {
  id: number;
  proposer: string;
  description: string;
  deadline: bigint;
  yesWeight: bigint;
  noWeight: bigint;
  finalized: boolean;
  passed: boolean;
}

export class DaoVoting {
  private readonly owner: string;
  private readonly quorumWeight: bigint;
  private nextId = 1;
  private weights = new LookupMap<bigint>("w:");
  private proposals = new LookupMap<Proposal>("p:");
  private receipts = new LookupMap<boolean>("v:");

  constructor(quorumWeight: bigint) {
    assert(quorumWeight > 0n, "Quorum weight must be positive");
    this.quorumWeight = quorumWeight;
    this.owner = near.predecessorAccountId();
  }

  setMemberWeight(account: string, weight: bigint): void {
    // TODO: enforce owner-only access and set member weight
  }

  createProposal(description: string, durationNs: bigint): number {
    // TODO: allow weighted members to create proposals with positive duration
    return 0;
  }

  vote(proposalId: number, support: boolean): void {
    // TODO: enforce active window, member weight > 0n, and no duplicate voting
  }

  finalize(proposalId: number): boolean {
    // TODO: enforce deadline passed and compute quorum + majority
    return false;
  }

  getProposal(proposalId: number): Proposal | null {
    return this.proposals.get(String(proposalId));
  }

  getMemberWeight(account: string): bigint {
    return this.weights.get(account) ?? 0n;
  }
}
