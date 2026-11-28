import { LookupMap, near, assert } from "near-sdk-js";

/**
 * Commitment hash: 64-bit FNV-1a over "<account>:<seed>:<salt>", hex encoded.
 * Stand-in for sha256 in this runtime. Provided; do not modify.
 */
export function hashCommitment(account: string, seed: bigint, salt: string): string {
  const data = `${account}:${seed.toString()}:${salt}`;
  let h = 0xcbf29ce484222325n;
  for (let i = 0; i < data.length; i++) {
    h ^= BigInt(data.charCodeAt(i));
    h = (h * 0x100000001b3n) & 0xffffffffffffffffn;
  }
  return h.toString(16).padStart(16, "0");
}

export class CommitRevealLottery {
  private readonly ticketPrice: bigint;
  private readonly bond: bigint;
  private readonly commitEndNs: bigint;
  private readonly revealEndNs: bigint;

  private commitments = new LookupMap<string>("c:");
  private revealed = new LookupMap<boolean>("r:");
  private balances = new LookupMap<bigint>("b:");
  private players: string[] = [];
  private revealers: string[] = [];
  private combinedSeed = 0n;
  private finalized = false;
  private winner = "";

  constructor(ticketPrice: bigint, bond: bigint, commitEndNs: bigint, revealEndNs: bigint) {
    assert(
      ticketPrice > 0n &&
        bond > 0n &&
        commitEndNs > near.blockTimestamp() &&
        revealEndNs > commitEndNs,
      "Invalid config"
    );
    this.ticketPrice = ticketPrice;
    this.bond = bond;
    this.commitEndNs = commitEndNs;
    this.revealEndNs = revealEndNs;
  }

  commit(commitment: string): void {
    assert(near.blockTimestamp() < this.commitEndNs, "Commit phase over");
    assert(commitment.length > 0, "Invalid commitment");
    assert(near.attachedDeposit() === this.ticketPrice + this.bond, "Wrong deposit");
    const caller = near.predecessorAccountId();
    assert(!this.commitments.containsKey(caller), "Already committed");
    this.commitments.set(caller, commitment);
    this.players.push(caller);
  }

  reveal(seed: bigint, salt: string): void {
    const now = near.blockTimestamp();
    assert(now >= this.commitEndNs && now < this.revealEndNs, "Not in reveal phase");
    const caller = near.predecessorAccountId();
    const commitment = this.commitments.get(caller);
    assert(commitment !== null, "No commitment");
    assert(!this.revealed.containsKey(caller), "Already revealed");
    assert(seed >= 0n, "Invalid seed");
    assert(hashCommitment(caller, seed, salt) === commitment, "Commitment mismatch");

    this.revealed.set(caller, true);
    this.revealers.push(caller);
    this.combinedSeed ^= seed;
    this.credit(caller, this.bond);
  }

  finalize(): string {
    assert(near.blockTimestamp() >= this.revealEndNs, "Reveal phase not over");
    assert(!this.finalized, "Already finalized");
    this.finalized = true;

    if (this.revealers.length === 0) {
      // No entropy was contributed, so there is no fair winner: unwind completely.
      for (const p of this.players) this.credit(p, this.ticketPrice + this.bond);
      return "";
    }

    const index = Number(this.combinedSeed % BigInt(this.revealers.length));
    this.winner = this.revealers[index] as string;
    const forfeited = BigInt(this.players.length - this.revealers.length);
    const pot = this.ticketPrice * BigInt(this.players.length) + this.bond * forfeited;
    this.credit(this.winner, pot);
    return this.winner;
  }

  withdraw(): bigint {
    const caller = near.predecessorAccountId();
    const amount = this.balances.get(caller) ?? 0n;
    assert(amount > 0n, "Nothing to withdraw");
    this.balances.set(caller, 0n);
    return amount;
  }

  getWinner(): string {
    return this.winner;
  }

  isFinalized(): boolean {
    return this.finalized;
  }

  hasRevealed(account: string): boolean {
    return this.revealed.containsKey(account);
  }

  playerCount(): number {
    return this.players.length;
  }

  revealCount(): number {
    return this.revealers.length;
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  private credit(account: string, amount: bigint): void {
    this.balances.set(account, (this.balances.get(account) ?? 0n) + amount);
  }
}
