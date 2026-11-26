import { NextResponse } from "next/server";
import { ConsinzoError } from "@consinzo/shared";
import { requireSessionUser } from "@/lib/auth";
import { getPublicChallengeBySlug, getServerReferenceSolution } from "@/lib/challenges";
import { handleApiError } from "@/lib/http";
import { readDb } from "@/lib/store";

export async function GET(
  _req: Request,
  context: { params: Promise<{ slug: string }> }
) {
  try {
    const user = await requireSessionUser();
    const { slug } = await context.params;
    const challenge = getPublicChallengeBySlug(slug);
    if (!challenge) {
      throw new ConsinzoError("NOT_FOUND", "Challenge not found.", 404);
    }

    const db = readDb();
    const unlock = db.unlocks.find(
      (u) => u.userId === user.id && u.challengeSlug === slug
    );
    const isAdmin = user.roles.some((r) => r === "super_admin" || r === "platform_admin");

    if (!unlock?.solutionUnlocked && !isAdmin) {
      throw new ConsinzoError(
        "SOLUTION_LOCKED",
        `Reference solution is locked under policy "${challenge.manifest.solution_unlock_policy}". Pass the challenge evaluation first.`,
        403
      );
    }

    const solution = getServerReferenceSolution(slug);
    if (!solution) {
      throw new ConsinzoError("NOT_FOUND", "Reference solution unavailable.", 404);
    }
    return NextResponse.json(solution);
  } catch (err) {
    return handleApiError(err);
  }
}
