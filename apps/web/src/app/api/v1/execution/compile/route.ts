import { NextResponse } from "next/server";
import { ConsinzoError } from "@consinzo/shared";
import { SnapshotSubmissionSchema, validateProjectSnapshot } from "@consinzo/validators";
import { getSessionUser } from "@/lib/auth";
import { getPublicChallengeBySlug } from "@/lib/challenges";
import { getDifficultyMeta, normalizeDifficulty } from "@/lib/difficulty";
import { getServerEnv } from "@/lib/env";
import { ACCOUNT_RUNS_PER_HOUR, GUEST_LIMITS, isGuestTier } from "@/lib/guest-limits";
import { handleApiError } from "@/lib/http";
import { checkRateLimit, getClientIp } from "@/lib/rate-limit";
import { getEcosystemRunner } from "@/lib/runner-dispatch";

const HOUR_MS = 60 * 60 * 1000;

/**
 * Runs the public test suite only. Open to guests with limits: a small hourly run budget
 * per network address, the entry difficulty tiers, and a shorter timeout. Signed-in users
 * get a larger budget. Hidden tests are never run or exposed here.
 */
export async function POST(req: Request) {
  try {
    const body = SnapshotSubmissionSchema.parse(await req.json());
    const challenge = getPublicChallengeBySlug(body.challengeSlug);
    if (!challenge) {
      throw new ConsinzoError("CHALLENGE_NOT_FOUND", "Challenge not found.", 404);
    }

    const session = await getSessionUser().catch(() => null);
    const isGuest = !session;
    const tier = normalizeDifficulty(challenge.manifest.difficulty);

    if (isGuest && !isGuestTier(tier)) {
      throw new ConsinzoError(
        "GUEST_TIER_LOCKED",
        `Sign in to run ${getDifficultyMeta(tier).label} challenges. Guests can run Beginner, Easy and Normal.`,
        403
      );
    }

    const limit = isGuest ? GUEST_LIMITS.RUNS_PER_HOUR : ACCOUNT_RUNS_PER_HOUR;
    const quota = checkRateLimit(
      isGuest ? `guest-run:${getClientIp(req)}` : `run:${session.id}`,
      limit,
      HOUR_MS
    );
    if (!quota.allowed) {
      const minutes = Math.max(1, Math.ceil((quota.resetAt - Date.now()) / 60_000));
      throw new ConsinzoError(
        isGuest ? "GUEST_LIMIT_REACHED" : "RATE_LIMITED",
        isGuest
          ? `Guest limit reached (${limit} runs per hour). Sign in for a free account to keep going, or wait about ${minutes} min.`
          : `Run limit reached (${limit} per hour). Try again in about ${minutes} min.`,
        429,
        { limit, resetAt: new Date(quota.resetAt).toISOString() }
      );
    }

    const { sanitizedFiles } = validateProjectSnapshot(body.files);
    const userSrc = sanitizedFiles.filter((f) => f.path.startsWith("src/"));
    const publicTests = challenge.publicTests.map((t) => ({
      path: t.path,
      content: t.content,
    }));

    const env = getServerEnv();
    const runner = getEcosystemRunner(challenge.manifest.ecosystem);
    const report = await runner.runTests([...userSrc, ...publicTests], {
      mode: "local-cli",
      timeoutMs: Math.min(
        challenge.manifest.tests.timeout_ms,
        env.executionTimeoutMs,
        isGuest ? GUEST_LIMITS.EXECUTION_TIMEOUT_MS : Number.POSITIVE_INFINITY
      ),
    });

    // Public-only test execution never runs or exposes hidden tests
    return NextResponse.json({
      ...report,
      hiddenTestsSummary: {
        evaluated: false,
        total: 0,
        passed: 0,
        failed: 0,
        notice: isGuest
          ? "Public check run only. Sign in and submit to run the hidden evaluation and earn points."
          : "Public check run only. Submit your solution to run server-isolated hidden evaluation.",
      },
      access: {
        guest: isGuest,
        limit,
        remaining: quota.remaining,
        resetAt: new Date(quota.resetAt).toISOString(),
      },
    });
  } catch (err) {
    return handleApiError(err);
  }
}
