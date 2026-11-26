import { ConsinzoError } from "@consinzo/shared";
import { getServerEnv } from "./env";
import { readDb } from "./store";

export function enforceSubmissionQuota(userId: string): {
  remainingThisHour: number;
  limitPerHour: number;
} {
  const { maxSubmissionsPerHour } = getServerEnv();
  const db = readDb();
  const oneHourAgo = Date.now() - 60 * 60 * 1000;

  const recentCount = db.submissions.filter(
    (s) => s.userId === userId && new Date(s.createdAt).getTime() >= oneHourAgo
  ).length;

  if (recentCount >= maxSubmissionsPerHour) {
    throw new ConsinzoError(
      "QUOTA_EXCEEDED",
      `Free-tier submission limit reached (${maxSubmissionsPerHour} submissions per hour). Please wait before submitting again.`,
      429,
      { used: recentCount, limit: maxSubmissionsPerHour }
    );
  }

  return {
    remainingThisHour: maxSubmissionsPerHour - recentCount,
    limitPerHour: maxSubmissionsPerHour,
  };
}
