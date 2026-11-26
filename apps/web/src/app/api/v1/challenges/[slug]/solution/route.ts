import { NextResponse } from "next/server";
import { ConsinzoError } from "@consinzo/shared";
import { requireSessionUser } from "@/lib/auth";
import { getPublicChallengeBySlug } from "@/lib/challenges";
import { loadPrivateReferenceSolution } from "@/lib/challenges/private-assets";
import { isSolutionUnlockedForUser } from "@/lib/data-adapter";
import { handleApiError } from "@/lib/http";

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

    const isAdmin = user.roles.some((r) => r === "super_admin" || r === "platform_admin");
    const unlocked = isAdmin || (await isSolutionUnlockedForUser(user.id, slug));

    if (!unlocked) {
      throw new ConsinzoError(
        "SOLUTION_LOCKED",
        `Reference solution is locked under policy "${challenge.manifest.solution_unlock_policy}". Pass the challenge evaluation first.`,
        403
      );
    }

    const solution = await loadPrivateReferenceSolution(slug);
    if (!solution) {
      throw new ConsinzoError("NOT_FOUND", "Reference solution unavailable.", 404);
    }
    return NextResponse.json(solution);
  } catch (err) {
    return handleApiError(err);
  }
}
