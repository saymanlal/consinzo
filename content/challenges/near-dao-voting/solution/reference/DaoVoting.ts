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
    assert(near.predecessorAccountId() === this.owner, "Unauthorized: owner only");
    assert(account.length > 0 && weight >= 0n, "Invalid member weight");
    this.weights.set(account, weight);
  }

  createProposal(description: string, durationNs: bigint): number {
    const proposer = near.predecessorAccountId();
    assert((this.weights.get(proposer) ?? 0n) > 0n, "Only weighted members can propose");
    assert(description.trim().length > 0 && durationNs > 0n, "Invalid proposal parameters");

    const id = this.nextId++;
    this.proposals.set(String(id), {
      id,
      proposer,
      description,
      deadline: near.blockTimestamp() + durationNs,
      yesWeight: 0n,
      noWeight: 0n,
      finalized: false,
      passed: false,
    });
    return id;
  }

  vote(proposalId: number, support: boolean): void {
    const proposal = this.proposals.get(String(proposalId));
    assert(proposal !== null, "Proposal not found");
    const p = proposal as Proposal;
    assert(!p.finalized, "Proposal already finalized");
    assert(near.blockTimestamp() <= p.deadline, "Voting period ended");

    const voter = near.predecessorAccountId();
    const weight = this.weights.get(voter) ?? 0n;
    assert(weight > 0n, "Caller has no voting weight");

    const receiptKey = `${proposalId}:${voter}`;
    assert(!this.receipts.containsKey(receiptKey), "Already voted");
    this.receipts.set(receiptKey, true);

    this.proposals.set(String(proposalId), {
      ...p,
      yesWeight: support ? p.yesWeight + weight : p.yesWeight,
      noWeight: support ? p.noWeight : p.noWeight + weight,
    });
  }

  finalize(proposalId: number): boolean {
    const proposal = this.proposals.get(String(proposalId));
    assert(proposal !== null, "Proposal not found");
    const p = proposal as Proposal;
    assert(!p.finalized, "Proposal already finalized");
    assert(near.blockTimestamp() > p.deadline, "Voting period still active");

    const passed = p.yesWeight >= this.quorumWeight && p.yesWeight > p.noWeight;
    this.proposals.set(String(proposalId), {
      ...p,
      finalized: true,
      passed,
    });
    return passed;
  }

  getProposal(proposalId: number): Proposal | null {
    return this.proposals.get(String(proposalId));
  }

  getMemberWeight(account: string): bigint {
    return this.weights.get(account) ?? 0n;
  }
}
