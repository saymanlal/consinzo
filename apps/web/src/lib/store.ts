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

interface LocalDatabase {
  users: StoredUser[];
  submissions: StoredSubmission[];
  unlocks: StoredUnlock[];
  bookmarks: Array<{ userId: string; challengeSlug: string; createdAt: string }>;
  achievements: Array<{ userId: string; achievementId: string; awardedAt: string }>;
  auditReports: StoredAuditReport[];
  contests: StoredContest[];
  adminAuditLogs: StoredAuditLog[];
}

function resolveDbPath(): string {
  const { dataDir } = getServerEnv();
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
    ],
    adminAuditLogs: [],
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
    return JSON.parse(fs.readFileSync(dbPath, "utf8")) as LocalDatabase;
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
