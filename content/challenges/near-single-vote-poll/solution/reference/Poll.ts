import { LookupMap, near, assert } from "near-sdk-js";

export class Poll {
  private options: string[] = [];
  private tallies: number[] = [];
  private choices = new LookupMap<number>("choice:");
  private total = 0;

  constructor(options: string[]) {
    assert(options.length >= 2, "Invalid options");
    const seen = new Set<string>();
    for (const label of options) {
      assert(label.length > 0 && !seen.has(label), "Invalid options");
      seen.add(label);
    }
    // Copy the labels so the caller cannot change the poll through the original array.
    this.options = [...options];
    this.tallies = options.map(() => 0);
  }

  private requireOption(option: number): void {
    assert(
      Number.isInteger(option) && option >= 0 && option < this.options.length,
      "Invalid option"
    );
  }

  vote(option: number): void {
    this.requireOption(option);
    const caller = near.predecessorAccountId();
    // containsKey, not a truthiness test: option 0 is a valid stored choice.
    assert(!this.choices.containsKey(caller), "Already voted");
    this.choices.set(caller, option);
    this.tallies[option] = (this.tallies[option] ?? 0) + 1;
    this.total += 1;
  }

  tally(option: number): number {
    this.requireOption(option);
    return this.tallies[option] ?? 0;
  }

  totalVotes(): number {
    return this.total;
  }

  hasVoted(account: string): boolean {
    return this.choices.containsKey(account);
  }

  choiceOf(account: string): number | null {
    return this.choices.get(account);
  }

  optionCount(): number {
    return this.options.length;
  }

  optionLabel(option: number): string {
    this.requireOption(option);
    return this.options[option] ?? "";
  }

  leading(): number {
    if (this.total === 0) return -1;
    let best = 0;
    for (let i = 1; i < this.tallies.length; i++) {
      // Strict comparison keeps the lowest index when counts are equal.
      if ((this.tallies[i] ?? 0) > (this.tallies[best] ?? 0)) best = i;
    }
    return best;
  }
}
