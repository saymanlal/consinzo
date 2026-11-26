import { FREE_TIER_LIMITS } from "@consinzo/shared";

const SECRET_ENV_PATTERN = /(SUPABASE_SERVICE_ROLE_KEY|CONSINZO_AUTH_SECRET|GITHUB_ACTIONS_EVAL_TOKEN|sk-[a-zA-Z0-9]{16,})/g;

export function sanitizeLogs(lines: string[], maxBytes = FREE_TIER_LIMITS.MAX_OUTPUT_BYTES): {
  logs: string[];
  truncated: boolean;
} {
  const cleaned: string[] = [];
  let byteCount = 0;
  let truncated = false;

  for (const raw of lines) {
    const scrubbed = raw
      .replace(SECRET_ENV_PATTERN, "[REDACTED]")
      .replace(/\/tmp\/consinzo-[a-zA-Z0-9_-]+/g, "/workspace");
    const size = Buffer.byteLength(scrubbed, "utf8") + 1;
    if (byteCount + size > maxBytes) {
      truncated = true;
      break;
    }
    byteCount += size;
    cleaned.push(scrubbed);
  }

  return { logs: cleaned, truncated };
}
