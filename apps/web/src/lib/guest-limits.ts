/** What a visitor without an account may do. Shared by the API, the workspace UI and the docs. */
export const GUEST_LIMITS = {
  /** Public-test runs per hour, per network address. */
  RUNS_PER_HOUR: 10,
  /** Execution timeout applied to guest runs. */
  EXECUTION_TIMEOUT_MS: 8_000,
} as const;
