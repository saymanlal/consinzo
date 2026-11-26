import crypto from "node:crypto";
import { calculateScore, type TestCaseOutcome } from "@consinzo/scoring";
import { getEcosystemRunner } from "./runner-dispatch";
import { ConsinzoError, type ExecutionMode, type ProjectFile } from "@consinzo/shared";
import { validateProjectSnapshot } from "@consinzo/validators";
import { getPublicChallengeBySlug } from "./challenges";
import { loadPrivateHiddenTestFiles } from "./challenges/private-assets";
import { saveEvaluatedSubmission } from "./data-adapter";
import { getServerEnv } from "./env";
import { enforceSubmissionQuota } from "./quotas";
import type { StoredSubmission } from "./store";

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

  await enforceSubmissionQuota(input.userId);
  const { sanitizedFiles } = validateProjectSnapshot(input.files);

  // Security: Strip user-submitted test/ files and enforce authoritative evaluation/public tests
  const userSrcFiles = sanitizedFiles.filter((f) => f.path.startsWith("src/"));
  const authoritativePublicTests = challenge.publicTests.map((t) => ({
    path: t.path,
    content: t.content,
  }));
  const hiddenTestFiles = await loadPrivateHiddenTestFiles(input.challengeSlug);

  const runner = getEcosystemRunner(challenge.manifest.ecosystem);
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
    diagnostics: report.diagnostics.map((d) => ({
      severity: d.severity,
      file: d.file,
      line: d.line,
      column: d.column,
      message: d.message,
    })),
    createdAt: new Date().toISOString(),
  };

  await saveEvaluatedSubmission(submission, {
    isSecurityMission: challenge.manifest.is_security_mission,
    unlockPolicy: challenge.manifest.solution_unlock_policy,
  });

  return submission;
}
