import { NextResponse } from "next/server";
import { EvmRunner } from "@consinzo/runner-evm";
import { ConsinzoError } from "@consinzo/shared";
import { SnapshotSubmissionSchema, validateProjectSnapshot } from "@consinzo/validators";
import { getPublicChallengeBySlug } from "@/lib/challenges";
import { getServerEnv } from "@/lib/env";
import { handleApiError } from "@/lib/http";

export async function POST(req: Request) {
  try {
    const body = SnapshotSubmissionSchema.parse(await req.json());
    const challenge = getPublicChallengeBySlug(body.challengeSlug);
    if (!challenge) {
      throw new ConsinzoError("CHALLENGE_NOT_FOUND", "Challenge not found.", 404);
    }

    const { sanitizedFiles } = validateProjectSnapshot(body.files);
    const userSrc = sanitizedFiles.filter((f) => f.path.startsWith("src/"));
    const publicTests = challenge.publicTests.map((t) => ({
      path: t.path,
      content: t.content,
    }));

    const env = getServerEnv();
    const runner = new EvmRunner();
    const report = await runner.runTests([...userSrc, ...publicTests], {
      mode: "local-cli",
      timeoutMs: Math.min(challenge.manifest.tests.timeout_ms, env.executionTimeoutMs),
    });

    // Public-only test execution never runs or exposes hidden tests
    return NextResponse.json({
      ...report,
      hiddenTestsSummary: {
        evaluated: false,
        total: 0,
        passed: 0,
        failed: 0,
        notice: "Public check run only. Submit your solution to run server-isolated hidden evaluation.",
      },
    });
  } catch (err) {
    return handleApiError(err);
  }
}
