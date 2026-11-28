import { LookupMap, near, assert } from "near-sdk-js";

export class Poll {
  private options: string[] = [];
  private tallies: number[] = [];
  private choices = new LookupMap<number>("choice:");
  private total = 0;

  constructor(options: string[]) {
    // TODO: require at least 2 non-empty, distinct labels ("Invalid options"), copy them and initialise one zero tally per option
  }

  private requireOption(option: number): void {
    // TODO: throw "Invalid option" unless option is an integer in [0, options.length)
  }

  vote(option: number): void {
    // TODO: validate the option, reject a second vote from the caller ("Already voted"), record the choice and update the tallies
    throw new Error("Not implemented");
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
    // TODO: return the index with the most votes (lowest index on a tie), or -1 when nobody has voted
    throw new Error("Not implemented");
  }
}
