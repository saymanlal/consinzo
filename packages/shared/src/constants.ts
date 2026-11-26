export const FREE_TIER_LIMITS = {
  MAX_PROJECT_BYTES: 256 * 1024, // 256 KB per snapshot
  MAX_FILES_PER_SNAPSHOT: 40,
  MAX_SUBMISSIONS_PER_HOUR: 20,
  MAX_EXECUTION_DURATION_MS: 15_000,
  MAX_OUTPUT_BYTES: 64 * 1024, // 64 KB sanitized log cap
  MAX_CONCURRENT_JOBS_PER_USER: 1,
  ARTIFACT_RETENTION_DAYS: 14,
} as const;

export const CHALLENGE_CATEGORIES = [
  { id: "programming-fundamentals", label: "Programming Fundamentals" },
  { id: "smart-contract-engineering", label: "Smart Contract Engineering" },
  { id: "protocol-implementation", label: "Protocol Implementation" },
  { id: "defi-engineering", label: "DeFi Engineering" },
  { id: "token-standards", label: "Token Standards" },
  { id: "blockchain-infrastructure", label: "Blockchain Infrastructure" },
  { id: "advanced-blockchain-systems", label: "Advanced Blockchain Systems" },
  { id: "security-engineering", label: "Security Engineering" },
  { id: "cross-chain-development", label: "Cross-Chain Development" },
  { id: "ecosystem-integrations", label: "Ecosystem Integrations" },
] as const;

export const ADMIN_ROLES = [
  "super_admin",
  "platform_admin",
  "challenge_manager",
  "ecosystem_manager",
  "security_reviewer",
  "competition_organizer",
  "content_editor",
] as const;
