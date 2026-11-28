import { LookupMap, near, assert } from "near-sdk-js";

export class DonationLedger {
  private donations = new LookupMap<bigint>("don:");
  private total = 0n;
  private donors = 0;
  private leader = "";
  private leaderTotal = 0n;

  donate(): bigint {
    // TODO: require a positive attached deposit ("Deposit required"), update the donor total, global total, donor count and top donor, return the donor's new total
    throw new Error("Not implemented");
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
