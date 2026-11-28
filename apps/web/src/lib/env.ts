import crypto from "node:crypto";

let ephemeralSecret: string | null = null;
let warnedAboutSecret = false;

/**
 * Secret for signing local-mode sessions and one-time tokens.
 *
 * In production a missing CONSINZO_AUTH_SECRET must never fall back to a value that is in
 * the source code, because anyone could then forge a session. Instead a random secret is
 * generated for this process: sessions stop working across restarts and instances, which is
 * a visible nudge to configure the variable, but they cannot be forged.
 */
function resolveAuthSecret(): string {
  const configured = process.env.CONSINZO_AUTH_SECRET;
  if (configured && !configured.includes("replace-with") && configured.length >= 16) {
    return configured;
  }
  if (process.env.NODE_ENV === "production") {
    if (!ephemeralSecret) ephemeralSecret = crypto.randomBytes(32).toString("hex");
    if (!warnedAboutSecret) {
      warnedAboutSecret = true;
      console.warn(
        "[consinzo] CONSINZO_AUTH_SECRET is not set. Using a random per-process secret: " +
          "local-mode sessions will not survive restarts or span instances. Set a 32-byte random value."
      );
    }
    return ephemeralSecret;
  }
  return "consinzo-local-dev-ephemeral-secret-change-in-prod";
}

export function getServerEnv() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";
  const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

  const isSupabaseConfigured =
    Boolean(supabaseUrl) &&
    !supabaseUrl.includes("your-project-ref") &&
    Boolean(supabaseAnonKey) &&
    !supabaseAnonKey.includes("your-supabase") &&
    Boolean(supabaseServiceRoleKey) &&
    !supabaseServiceRoleKey.includes("your-supabase");

  const authSecret = resolveAuthSecret();

  return {
    isSupabaseConfigured,
    supabaseUrl,
    supabaseAnonKey,
    supabaseServiceRoleKey,
    authSecret,
    dataDir: process.env.CONSINZO_DATA_DIR || ".data",
    enableLocalEvmRunner: process.env.CONSINZO_ENABLE_LOCAL_EVM_RUNNER !== "false",
    enableRemoteActionsEval: process.env.CONSINZO_ENABLE_REMOTE_ACTIONS_EVAL === "true",
    maxSubmissionsPerHour: Number(process.env.CONSINZO_MAX_SUBMISSIONS_PER_HOUR || 20),
    executionTimeoutMs: Number(process.env.CONSINZO_EXECUTION_TIMEOUT_MS || 15000),
  };
}
