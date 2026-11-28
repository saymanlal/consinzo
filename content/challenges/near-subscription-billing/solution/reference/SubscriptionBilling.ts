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
    assert(near.predecessorAccountId() === this.owner, "Not owner");
    assert(price > 0n && periodNs > 0n, "Invalid plan");
    const id = this.nextPlanId++;
    this.plans.set(String(id), { price, periodNs });
    return id;
  }

  fund(): void {
    const amount = near.attachedDeposit();
    assert(amount > 0n, "Zero deposit");
    const caller = near.predecessorAccountId();
    this.balances.set(caller, this.balanceOf(caller) + amount);
  }

  subscribe(planId: number): void {
    const plan = this.plans.get(String(planId));
    assert(plan !== null, "Plan not found");
    const p = plan as Plan;
    const caller = near.predecessorAccountId();
    this.settle(caller);
    const existing = this.subs.get(caller);
    assert(existing === null || existing.status !== "ACTIVE", "Already subscribed");
    const balance = this.balanceOf(caller);
    assert(balance >= p.price, "Insufficient balance");

    this.balances.set(caller, balance - p.price);
    this.merchantEarnings += p.price;
    this.subs.set(caller, {
      planId,
      paidUntil: near.blockTimestamp() + p.periodNs,
      cancelRequested: false,
      status: "ACTIVE",
    });
  }

  charge(account: string): number {
    assert(this.subs.containsKey(account), "No subscription");
    return this.settle(account);
  }

  cancel(): void {
    const caller = near.predecessorAccountId();
    this.settle(caller);
    const sub = this.subs.get(caller);
    assert(sub !== null && sub.status === "ACTIVE", "No active subscription");
    this.subs.set(caller, { ...(sub as Subscription), cancelRequested: true });
  }

  withdrawBalance(amount: bigint): bigint {
    const caller = near.predecessorAccountId();
    // Collect what is already owed before letting funds leave.
    this.settle(caller);
    const balance = this.balanceOf(caller);
    assert(amount > 0n && amount <= balance, "Insufficient balance");
    this.balances.set(caller, balance - amount);
    return amount;
  }

  collectEarnings(): bigint {
    assert(near.predecessorAccountId() === this.owner, "Not owner");
    const amount = this.merchantEarnings;
    this.merchantEarnings = 0n;
    return amount;
  }

  isActive(account: string): boolean {
    const sub = this.subs.get(account);
    return sub !== null && sub.status === "ACTIVE" && near.blockTimestamp() < sub.paidUntil;
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

  /** Charges every period that is due. Returns the number of periods charged. */
  private settle(account: string): number {
    const stored = this.subs.get(account);
    if (stored === null || stored.status !== "ACTIVE") return 0;
    const sub: Subscription = { ...stored };
    const plan = this.plans.get(String(sub.planId)) as Plan;
    const now = near.blockTimestamp();
    let balance = this.balanceOf(account);
    let charged = 0;

    while (sub.status === "ACTIVE" && now >= sub.paidUntil) {
      if (sub.cancelRequested) {
        sub.status = "CANCELLED";
      } else if (balance < plan.price) {
        sub.status = "LAPSED";
      } else {
        balance -= plan.price;
        this.merchantEarnings += plan.price;
        // Advance from the due date, not from `now`, so late keepers do not gift time.
        sub.paidUntil += plan.periodNs;
        charged++;
      }
    }

    this.balances.set(account, balance);
    this.subs.set(account, sub);
    return charged;
  }
}
