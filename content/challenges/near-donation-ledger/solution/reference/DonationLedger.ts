import { LookupMap, near, assert } from "near-sdk-js";

export class DonationLedger {
  private donations = new LookupMap<bigint>("don:");
  private total = 0n;
  private donors = 0;
  private leader = "";
  private leaderTotal = 0n;

  donate(): bigint {
    const amount = near.attachedDeposit();
    assert(amount > 0n, "Deposit required");
    const donor = near.predecessorAccountId();

    const previous = this.donations.get(donor);
    if (previous === null) this.donors += 1;
    const updated = (previous ?? 0n) + amount;
    this.donations.set(donor, updated);
    this.total += amount;

    // The comparison uses the cumulative total, and is strict so that a tie keeps the current leader.
    if (updated > this.leaderTotal) {
      this.leader = donor;
      this.leaderTotal = updated;
    }
    return updated;
  }

  donationOf(account: string): bigint {
    return this.donations.get(account) ?? 0n;
  }

  totalDonated(): bigint {
    return this.total;
  }

  donorCount(): number {
    return this.donors;
  }

  topDonor(): string {
    return this.leader;
  }

  topDonation(): bigint {
    return this.leaderTotal;
  }
}
