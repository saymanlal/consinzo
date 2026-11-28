import { LookupMap, near, assert } from "near-sdk-js";

export type SubStatus = "ACTIVE" | "CANCELLED" | "LAPSED";

export interface Plan {
  price: bigint;
  periodNs: bigint;
}

export interface Subscription {
  planId: number;
  paidUntil: bigint;
  cancelRequested: boolean;
  status: SubStatus;
}

export class SubscriptionBilling {
  private readonly owner: string;
  private plans = new LookupMap<Plan>("p:");
  private subs = new LookupMap<Subscription>("s:");
  private balances = new LookupMap<bigint>("b:");
  private merchantEarnings = 0n;
  private nextPlanId = 1;

  constructor() {
    this.owner = near.predecessorAccountId();
  }

  createPlan(price: bigint, periodNs: bigint): number {
    // TODO: owner only; validate; return the new plan id (starting at 1)
    return 0;
  }

  fund(): void {
    // TODO: credit the attached deposit to the caller's prepaid balance
  }

  subscribe(planId: number): void {
    // TODO: settle, reject active subscribers, charge the first period, store the subscription
  }

  charge(account: string): number {
    // TODO: settle every due period of `account`; return how many were charged
    return 0;
  }

  cancel(): void {
    // TODO: settle, then flag the subscription to end at paidUntil
  }

  withdrawBalance(amount: bigint): bigint {
    // TODO: settle first, then withdraw unused prepaid funds
    return 0n;
  }

  collectEarnings(): bigint {
    // TODO: owner only; return and reset the merchant earnings
    return 0n;
  }

  isActive(account: string): boolean {
    // TODO: ACTIVE and inside the paid period
    return false;
  }

  getSubscription(account: string): Subscription | null {
    return this.subs.get(account);
  }

  getPlan(planId: number): Plan | null {
    return this.plans.get(String(planId));
  }

  balanceOf(account: string): bigint {
    return this.balances.get(account) ?? 0n;
  }

  earnings(): bigint {
    return this.merchantEarnings;
  }
}
