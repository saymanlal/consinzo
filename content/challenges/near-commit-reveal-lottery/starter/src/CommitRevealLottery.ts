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
    // TODO: validate the configuration ("Invalid config")
    this.ticketPrice = ticketPrice;
    this.bond = bond;
    this.commitEndNs = commitEndNs;
    this.revealEndNs = revealEndNs;
  }

  commit(commitment: string): void {
    // TODO: commit phase only, exact deposit, one commitment per account
  }

  reveal(seed: bigint, salt: string): void {
    // TODO: reveal phase only; verify the commitment, return the bond, mix the seed
  }

  finalize(): string {
    // TODO: after the reveal phase, pick the winner and credit the pot (or refund everyone)
    return "";
  }

  withdraw(): bigint {
    // TODO: pay out and zero the caller's balance
    return 0n;
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
}
