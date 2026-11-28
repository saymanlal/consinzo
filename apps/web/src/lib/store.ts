import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import type { ExecutionMode, RoleName, SubmissionStatus } from "@consinzo/shared";
import { getServerEnv } from "./env";

export interface StoredUser {
  id: string;
  email: string;
  username: string;
  displayName: string;
  bio: string;
  githubUrl: string;
  websiteUrl: string;
  passwordHash: string;
  /** Checksummed EVM address when the account signs in with a wallet. Public data only. */
  walletAddress?: string;
  /** E.164 phone number when the account signs in by SMS code. */
  phone?: string;
  /** How the account was first created. */
  authProvider?: "password" | "wallet" | "email-code" | "phone";
  roles: RoleName[];
  totalPoints: number;
  challengesCompleted: number;
  securityMissionsCompleted: number;
  createdAt: string;
}

export interface StoredSubmission {
  id: string;
  userId: string;
  challengeSlug: string;
  executionMode: ExecutionMode;
  runnerName: string;
  compilerVersion: string;
  status: SubmissionStatus;
  compiled: boolean;
  score: number;
  maxPoints: number;
  passed: boolean;
  durationMs: number;
  averageGasUsed?: number;
  scoringBreakdown: Record<string, unknown>;
  publicTests: Array<{
    name: string;
    contract: string;
    passed: boolean;
    gasUsed?: number;
    durationMs: number;
    reason?: string;
  }>;
  hiddenSummary?: {
    evaluated: boolean;
    total: number;
    passed: number;
    failed: number;
  };
  sanitizedLogs: string[];
  diagnostics?: Array<{
    severity: "error" | "warning" | "info";
    file: string;
    line?: number;
    column?: number;
    message: string;
  }>;
  createdAt: string;
}

export interface StoredUnlock {
  userId: string;
  challengeSlug: string;
  passed: boolean;
  attempts: number;
  bestScore: number;
  solutionUnlocked: boolean;
  unlockedAt?: string;
}

export interface StoredAuditReport {
  id: string;
  missionSlug: string;
  authorId: string;
  authorUsername: string;
  title: string;
  severity: "critical" | "high" | "medium" | "low" | "informational";
  affectedComponent: string;
  rootCause: string;
  attackScenario: string;
  impact: string;
  proofOfConcept: string;
  recommendedRemediation: string;
  status: "submitted" | "under_review" | "accepted" | "needs_revision";
  reviewerFeedback?: string;
  createdAt: string;
}

export interface StoredContest {
  slug: string;
  title: string;
  description: string;
  contestType: "coding" | "security" | "university" | "sponsored";
  visibility: "public" | "private";
  startsAt: string;
  endsAt: string;
  challengeSlugs: string[];
  organizerId: string;
  registeredUserIds: string[];
}

export interface StoredAuditLog {
  id: string;
  actorId: string;
  action: string;
  targetType: string;
  targetId: string;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface StoredTeam {
  id: string;
  contestSlug: string;
  name: string;
  captainId: string;
  memberIds: string[];
  createdAt: string;
}

export interface StoredContestScore {
  contestSlug: string;
  userId: string;
  totalScore: number;
  lastAcceptedAt: string;
}

export interface StoredOtpChallenge {
  channel: "email" | "phone";
  identifier: string;
  codeHash: string;
  expiresAt: number;
  attempts: number;
}

export interface StoredContactMessage {
  id: string;
  name: string;
  email: string;
  topic: string;
  message: string;
  createdAt: string;
}

interface LocalDatabase {
  users: StoredUser[];
  submissions: StoredSubmission[];
  unlocks: StoredUnlock[];
  bookmarks: Array<{ userId: string; challengeSlug: string; createdAt: string }>;
  achievements: Array<{ userId: string; achievementId: string; awardedAt: string }>;
  auditReports: StoredAuditReport[];
  contests: StoredContest[];
  teams: StoredTeam[];
  contestScores: StoredContestScore[];
  adminAuditLogs: StoredAuditLog[];
  contactMessages: StoredContactMessage[];
  otpChallenges: StoredOtpChallenge[];
}

function resolveDbPath(): string {
  const { dataDir } = getServerEnv();
  // Vercel serverless filesystem (/var/task) is read-only; use /tmp for ephemeral local fallback
  if (process.env.VERCEL === "1" || process.env.AWS_LAMBDA_FUNCTION_NAME) {
    const tmpDir = path.join("/tmp", "consinzo-data");
    fs.mkdirSync(tmpDir, { recursive: true });
    return path.join(tmpDir, "consinzo-db.json");
  }
  const candidates = [
    path.resolve(process.cwd(), dataDir),
    path.resolve(process.cwd(), "../..", dataDir),
  ];
  const baseDir = fs.existsSync(path.resolve(process.cwd(), "content"))
    ? candidates[0]!
    : candidates[1]!;
  fs.mkdirSync(baseDir, { recursive: true });
  return path.join(baseDir, "consinzo-db.json");
}

function initialSeedDb(): LocalDatabase {
  return {
    users: [],
    submissions: [],
    unlocks: [],
    bookmarks: [],
    achievements: [],
    auditReports: [],
    contests: [
      {
        slug: "evm-security-sprint-01",
        title: "EVM Protocol & Security Sprint #01",
        description:
          "Timed engineering sprint covering ERC-20 invariants, reentrancy defense, and constant-product AMM accounting.",
        contestType: "security",
        visibility: "public",
        startsAt: "2026-11-20T00:00:00.000Z",
        endsAt: "2026-12-31T23:59:59.000Z",
        challengeSlugs: [
          "erc20-token-vault",
          "reentrancy-vault-defense",
          "constant-product-amm",
        ],
        organizerId: "system",
        registeredUserIds: [],
      },
      {
        slug: "near-ts-builder-sprint-01",
        title: "NEAR TypeScript Builder Sprint #01",
        description:
          "Multi-ecosystem engineering sprint covering NEAR predecessor attribution, LookupMap timelocked escrow, and weighted DAO governance.",
        contestType: "coding",
        visibility: "public",
        startsAt: "2026-11-25T00:00:00.000Z",
        endsAt: "2026-12-31T23:59:59.000Z",
        challengeSlugs: [
          "near-counter-contract",
          "near-ft-escrow",
          "near-dao-voting",
        ],
        organizerId: "system",
        registeredUserIds: [],
      },
    ],
    teams: [],
    contestScores: [],
    adminAuditLogs: [],
    contactMessages: [],
    otpChallenges: [],
  };
}

export function readDb(): LocalDatabase {
  const dbPath = resolveDbPath();
  if (!fs.existsSync(dbPath)) {
    const seed = initialSeedDb();
    fs.writeFileSync(dbPath, JSON.stringify(seed, null, 2), "utf8");
    return seed;
  }
  try {
    const parsed = JSON.parse(fs.readFileSync(dbPath, "utf8")) as Partial<LocalDatabase>;
    return {
      ...initialSeedDb(),
      ...parsed,
      contests:
        parsed.contests && parsed.contests.length > 0
          ? [
              ...parsed.contests,
              ...initialSeedDb().contests.filter(
                (seeded) => !parsed.contests!.some((existing) => existing.slug === seeded.slug)
              ),
            ]
          : initialSeedDb().contests,
      teams: parsed.teams ?? [],
      contestScores: parsed.contestScores ?? [],
    };
  } catch {
    const seed = initialSeedDb();
    fs.writeFileSync(dbPath, JSON.stringify(seed, null, 2), "utf8");
    return seed;
  }
}

export function writeDb(db: LocalDatabase): void {
  const dbPath = resolveDbPath();
  const tmpPath = `${dbPath}.${crypto.randomUUID()}.tmp`;
  fs.writeFileSync(tmpPath, JSON.stringify(db, null, 2), "utf8");
  fs.renameSync(tmpPath, dbPath);
}
