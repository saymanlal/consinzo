import crypto from "node:crypto";
import { EvmRunner } from "@consinzo/runner-evm";
import { calculateScore, type TestCaseOutcome } from "@consinzo/scoring";
import { ConsinzoError, type ExecutionMode, type ProjectFile } from "@consinzo/shared";
import { validateProjectSnapshot } from "@consinzo/validators";
import { getPublicChallengeBySlug, getServerHiddenTestFiles } from "./challenges";
import { getServerEnv } from "./env";
import { enforceSubmissionQuota } from "./quotas";
import { readDb, writeDb, type StoredSubmission } from "./store";

export async function executeAndScoreSubmission(input: {
  userId: string;
  challengeSlug: string;
  mode: ExecutionMode;
  files: ProjectFile[];
}): Promise<StoredSubmission> {
  const env = getServerEnv();
  if (input.mode === "remote-actions" && !env.enableRemoteActionsEval) {
    throw new ConsinzoError(
      "REMOTE_EVAL_UNAVAILABLE",
      "Mode C remote GitHub Actions evaluation is disabled in this environment because isolated microVM runners are not configured. Use Local EVM Runner.",
      503
    );
  }

  const challenge = getPublicChallengeBySlug(input.challengeSlug);
  if (!challenge) {
    throw new ConsinzoError("CHALLENGE_NOT_FOUND", "Challenge not found.", 404);
  }

  enforceSubmissionQuota(input.userId);
  const { sanitizedFiles } = validateProjectSnapshot(input.files);

  // Security: Strip user-submitted test/ files and enforce authoritative evaluation/public tests
  const userSrcFiles = sanitizedFiles.filter((f) => f.path.startsWith("src/"));
  const authoritativePublicTests = challenge.publicTests.map((t) => ({
    path: t.path,
    content: t.content,
  }));
  const hiddenTestFiles = getServerHiddenTestFiles(input.challengeSlug);

  const runner = new EvmRunner();
  const report = await runner.runTests([...userSrcFiles, ...authoritativePublicTests], {
    mode: input.mode,
    timeoutMs: Math.min(challenge.manifest.tests.timeout_ms, env.executionTimeoutMs),
    includeHiddenFiles: hiddenTestFiles,
  });

  const publicOutcomes: TestCaseOutcome[] = report.publicTests.map((t) => ({
    name: t.name,
    passed: t.passed,
    suite: "public",
    gasUsed: t.gasUsed,
    durationMs: t.durationMs,
    errorMessage: t.reason,
  }));

  // Build synthetic hidden outcomes array from hiddenSummary counts (names never leave server)
  const hiddenOutcomes: TestCaseOutcome[] = [];
  if (report.hiddenTestsSummary?.evaluated) {
    for (let i = 0; i < report.hiddenTestsSummary.passed; i++) {
      hiddenOutcomes.push({ name: `h_${i}`, passed: true, suite: "hidden" });
    }
    for (let i = 0; i < report.hiddenTestsSummary.failed; i++) {
      hiddenOutcomes.push({ name: `hf_${i}`, passed: false, suite: "hidden" });
    }
  }

  const warningCount = report.diagnostics.filter((d) => d.severity === "warning").length;
  const scoringBreakdown = calculateScore({
    maxPoints: challenge.manifest.scoring.max_points,
    weights: challenge.manifest.scoring.weights,
    compiled: report.compiled,
    compilerWarningsCount: warningCount,
    gasBudget: challenge.manifest.scoring.gas_budget,
    averageGasUsed: report.averageGasUsed,
    publicResults: publicOutcomes,
    hiddenResults: hiddenOutcomes,
  });

  const submission: StoredSubmission = {
    id: crypto.randomUUID(),
    userId: input.userId,
    challengeSlug: input.challengeSlug,
    executionMode: report.mode,
    runnerName: report.runnerName,
    compilerVersion: report.compilerVersion,
    status: report.status,
    compiled: report.compiled,
    score: scoringBreakdown.totalScore,
    maxPoints: scoringBreakdown.maxPoints,
    passed: scoringBreakdown.passed,
    durationMs: report.totalDurationMs,
    averageGasUsed: report.averageGasUsed,
    scoringBreakdown: scoringBreakdown as unknown as Record<string, unknown>,
    publicTests: report.publicTests,
    hiddenSummary: report.hiddenTestsSummary
      ? {
          evaluated: report.hiddenTestsSummary.evaluated,
          total: report.hiddenTestsSummary.total,
          passed: report.hiddenTestsSummary.passed,
          failed: report.hiddenTestsSummary.failed,
        }
      : undefined,
    sanitizedLogs: report.sanitizedLogs,
    createdAt: new Date().toISOString(),
  };

  // Persist submission, unlock state, user points, and server-verified achievements
  const db = readDb();
  db.submissions.unshift(submission);

  let unlock = db.unlocks.find(
    (u) => u.userId === input.userId && u.challengeSlug === input.challengeSlug
  );
  const previouslyPassed = Boolean(unlock?.passed);
  const previousBest = unlock?.bestScore ?? 0;

  if (!unlock) {
    unlock = {
      userId: input.userId,
      challengeSlug: input.challengeSlug,
      passed: submission.passed,
      attempts: 1,
      bestScore: submission.score,
      solutionUnlocked: submission.passed,
      unlockedAt: submission.passed ? submission.createdAt : undefined,
    };
    db.unlocks.push(unlock);
  } else {
    unlock.attempts += 1;
    if (submission.score > unlock.bestScore) {
      unlock.bestScore = submission.score;
    }
    if (submission.passed && !unlock.passed) {
      unlock.passed = true;
      unlock.solutionUnlocked = true;
      unlock.unlockedAt = submission.createdAt;
    }
    if (
      challenge.manifest.solution_unlock_policy === "after_3_attempts" &&
      unlock.attempts >= 3 &&
      !unlock.solutionUnlocked
    ) {
      unlock.solutionUnlocked = true;
      unlock.unlockedAt = submission.createdAt;
    }
  }

  const user = db.users.find((u) => u.id === input.userId);
  if (user) {
    if (submission.score > previousBest) {
      user.totalPoints = Math.round((user.totalPoints + (submission.score - previousBest)) * 100) / 100;
    }
    if (submission.passed && !previouslyPassed) {
      user.challengesCompleted += 1;
      if (challenge.manifest.is_security_mission) {
        user.securityMissionsCompleted += 1;
      }

      const award = (achievementId: string) => {
        if (
          !db.achievements.some(
            (a) => a.userId === user.id && a.achievementId === achievementId
          )
        ) {
          db.achievements.push({
            userId: user.id,
            achievementId,
            awardedAt: submission.createdAt,
          });
        }
      };

      award("first-verified-pass");
      if (challenge.manifest.is_security_mission) {
        award("security-defender");
      }
      const passedSlugs = new Set(
        db.unlocks.filter((u) => u.userId === user.id && u.passed).map((u) => u.challengeSlug)
      );
      if (passedSlugs.has("erc20-token-vault") && passedSlugs.has("erc721-royalty-nft")) {
        award("evm-token-architect");
      }
    }
  }

  writeDb(db);
  return submission;
}
