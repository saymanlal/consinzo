/** What a visitor without an account may do. Shared by the API, the workspace UI and the docs. */
export const GUEST_LIMITS = {
  /** Public-test runs per hour, per network address. */
  RUNS_PER_HOUR: 10,
  /** Execution timeout applied to guest runs. */
  EXECUTION_TIMEOUT_MS: 8_000,
  /** Difficulty tiers a guest may run. Higher tiers need an account. */
  TIERS: ["beginner", "easy", "normal"],
} as const;

/** Public-test runs per hour for a signed-in account (submissions have their own quota). */
export const ACCOUNT_RUNS_PER_HOUR = 120;

export function isGuestTier(difficulty: string): boolean {
  return (GUEST_LIMITS.TIERS as readonly string[]).includes(difficulty);
}
