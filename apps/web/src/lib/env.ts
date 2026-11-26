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

  const authSecret =
    process.env.CONSINZO_AUTH_SECRET &&
    !process.env.CONSINZO_AUTH_SECRET.includes("replace-with")
      ? process.env.CONSINZO_AUTH_SECRET
      : "consinzo-local-dev-ephemeral-secret-change-in-prod";

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
