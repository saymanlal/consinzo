import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const tmpDataDir = fs.mkdtempSync(path.join(os.tmpdir(), "consinzo-test-db-"));
process.env.CONSINZO_DATA_DIR = tmpDataDir;
process.env.CONSINZO_AUTH_SECRET = "test-secret-0123456789abcdef0123456789";

let currentMockUserId: string | null = null;

vi.mock("next/headers", () => ({
  cookies: async () => ({
    get: (name: string) => {
      if (name === "consinzo_session" && currentMockUserId) {
        return { value: currentMockUserId };
      }
      return undefined;
    },
  }),
}));

import { createUserAccount, signSessionToken } from "./auth";
import { getPublicChallengeBySlug } from "./challenges";
import { executeAndScoreSubmission } from "./evaluation-service";
import { readDb, writeDb } from "./store";
import { GET as getAdminOverview } from "../app/api/v1/admin/overview/route";
import { GET as getSolution } from "../app/api/v1/challenges/[slug]/solution/route";
import { PATCH as patchProfile } from "../app/api/v1/profiles/route";
import { GET as getSubmissions } from "../app/api/v1/submissions/route";

describe("CONSINZO Phase 1 Security, Authorization & ERC-20 Workflow", () => {
  let aliceId = "";
  let bobId = "";

  beforeAll(() => {
    const alice = createUserAccount({
      email: "alice@consinzo.test",
      username: "alice_dev",
      displayName: "Alice Dev",
      password: "StrongPassword123!",
    });
    const bob = createUserAccount({
      email: "bob@consinzo.test",
      username: "bob_dev",
      displayName: "Bob Dev",
      password: "StrongPassword123!",
    });
    aliceId = alice.id;
    bobId = bob.id;
  });

  afterAll(() => {
    fs.rmSync(tmpDataDir, { recursive: true, force: true });
  });

  it("1. Rejects anonymous access to private submissions, solutions, and admin endpoints", async () => {
    currentMockUserId = null;

    const subRes = await getSubmissions(new Request("http://localhost/api/v1/submissions"));
    expect(subRes.status).toBe(401);

    const solRes = await getSolution(new Request("http://localhost/api/v1/challenges/erc20-token-vault/solution"), {
      params: Promise.resolve({ slug: "erc20-token-vault" }),
    });
    expect(solRes.status).toBe(401);

    const adminRes = await getAdminOverview();
    expect(adminRes.status).toBe(401);
  });

  it("2. Rejects non-admin users from admin endpoints (403 Forbidden)", async () => {
    currentMockUserId = signSessionToken({ userId: aliceId, exp: Date.now() + 60_000 });
    const adminRes = await getAdminOverview();
    expect(adminRes.status).toBe(403);
  });

  it("3. Never exposes hidden tests or reference solutions on PublicChallengeView", () => {
    const pub = getPublicChallengeBySlug("erc20-token-vault");
    expect(pub).not.toBeNull();
    const serialized = JSON.stringify(pub);
    expect(serialized).not.toContain("testHiddenInfiniteAllowanceNotDecremented");
    expect(serialized).not.toContain("testHiddenNonOwnerCannotMint");
    expect(pub?.hasHiddenTests).toBe(true);
  });

  it("4. Prevents users from mutating their own scores via profile PATCH", async () => {
    currentMockUserId = signSessionToken({ userId: aliceId, exp: Date.now() + 60_000 });
    const req = new Request("http://localhost/api/v1/profiles", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        displayName: "Alice Updated",
        totalPoints: 999999,
        challengesCompleted: 500,
      }),
    });
    const res = await patchProfile(req);
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.profile.displayName).toBe("Alice Updated");
    expect(json.profile.totalPoints).toBe(0);
    expect(json.profile.challengesCompleted).toBe(0);
  });

  it("5. Runs complete ERC-20 workflow: starter fails, reference passes public+hidden, unlocks solution & awards achievement", async () => {
    currentMockUserId = signSessionToken({ userId: aliceId, exp: Date.now() + 60_000 });

    // Reference solution still locked before passing
    const lockedRes = await getSolution(
      new Request("http://localhost/api/v1/challenges/erc20-token-vault/solution"),
      { params: Promise.resolve({ slug: "erc20-token-vault" }) }
    );
    expect(lockedRes.status).toBe(403);

    // 1) Submit unedited starter -> fails public & hidden tests
    const challenge = getPublicChallengeBySlug("erc20-token-vault")!;
    const failSub = await executeAndScoreSubmission({
      userId: aliceId,
      challengeSlug: "erc20-token-vault",
      mode: "local-cli",
      files: challenge.starterFiles.map((f) => ({ path: f.path, content: f.content })),
    });
    expect(failSub.compiled).toBe(true);
    expect(failSub.passed).toBe(false);
    expect(failSub.score).toBeLessThan(100);

    // 2) Submit genuine ERC-20 solution (even if user tries to tamper with test/ files, server strips them!)
    const validSolCode = fs.readFileSync(
      path.resolve(
        process.cwd(),
        "../../content/challenges/erc20-token-vault/solution/reference/ConsinzoToken.sol"
      ),
      "utf8"
    );
    const passSub = await executeAndScoreSubmission({
      userId: aliceId,
      challengeSlug: "erc20-token-vault",
      mode: "local-cli",
      files: [
        { path: "src/ConsinzoToken.sol", content: validSolCode },
        { path: "test/ConsinzoToken.t.sol", content: "// tampered empty test ignored by server" },
      ],
    });

    expect(passSub.compiled).toBe(true);
    expect(passSub.passed).toBe(true);
    expect(passSub.score).toBe(100);
    expect(passSub.hiddenSummary?.evaluated).toBe(true);
    expect(passSub.hiddenSummary?.passed).toBe(4);
    expect(passSub.hiddenSummary?.total).toBe(4);

    // Solution is now unlocked for Alice
    const unlockedRes = await getSolution(
      new Request("http://localhost/api/v1/challenges/erc20-token-vault/solution"),
      { params: Promise.resolve({ slug: "erc20-token-vault" }) }
    );
    expect(unlockedRes.status).toBe(200);

    // Bob cannot see Alice's private submissions
    currentMockUserId = signSessionToken({ userId: bobId, exp: Date.now() + 60_000 });
    const bobSubsRes = await getSubmissions(new Request("http://localhost/api/v1/submissions"));
    const bobSubsJson = await bobSubsRes.json();
    expect(bobSubsJson.submissions).toHaveLength(0);

    // Alice earned server-verified points and first-verified-pass achievement
    const db = readDb();
    const alice = db.users.find((u) => u.id === aliceId)!;
    expect(alice.totalPoints).toBe(100);
    expect(alice.challengesCompleted).toBe(1);
    expect(
      db.achievements.some((a) => a.userId === aliceId && a.achievementId === "first-verified-pass")
    ).toBe(true);
  });

  it("6. Enforces hourly submission quota", async () => {
    const db = readDb();
    for (let i = 0; i < 20; i++) {
      db.submissions.push({
        id: `quota-${i}`,
        userId: bobId,
        challengeSlug: "erc20-token-vault",
        executionMode: "local-cli",
        runnerName: "solc-ethereumjs-evm",
        compilerVersion: "0.8.28",
        status: "failed",
        compiled: true,
        score: 0,
        maxPoints: 100,
        passed: false,
        durationMs: 10,
        scoringBreakdown: {},
        publicTests: [],
        sanitizedLogs: [],
        createdAt: new Date().toISOString(),
      });
    }
    writeDb(db);

    const challenge = getPublicChallengeBySlug("erc20-token-vault")!;
    await expect(
      executeAndScoreSubmission({
        userId: bobId,
        challengeSlug: "erc20-token-vault",
        mode: "local-cli",
        files: challenge.starterFiles.map((f) => ({ path: f.path, content: f.content })),
      })
    ).rejects.toThrow(/quota|limit/i);
  });
});
