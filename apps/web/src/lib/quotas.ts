import { ConsinzoError } from "@consinzo/shared";
import { countRecentSubmissions } from "./data-adapter";
import { getServerEnv } from "./env";

export async function enforceSubmissionQuota(userId: string): Promise<{
  remainingThisHour: number;
  limitPerHour: number;
}> {
  const { maxSubmissionsPerHour } = getServerEnv();
  const oneHourAgoIso = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const recentCount = await countRecentSubmissions(userId, oneHourAgoIso);

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
