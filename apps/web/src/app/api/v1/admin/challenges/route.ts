import path from "node:path";
import { NextResponse } from "next/server";
import { validateChallengeDirectory } from "@consinzo/validators";
import { requireAdminRole } from "@/lib/auth";
import { getChallengesRootOrThrow } from "@/lib/challenges/queries";
import { getPublishedChallenges } from "@/lib/challenges";
import { handleApiError } from "@/lib/http";

export async function GET() {
  try {
    await requireAdminRole([
      "super_admin",
      "platform_admin",
      "challenge_manager",
      "content_editor",
    ]);

    const challenges = getPublishedChallenges();
    const root = getChallengesRootOrThrow();

    const inventory = challenges.map((c) => {
      const check = validateChallengeDirectory(path.join(root, c.slug));
      return {
        id: c.id,
        slug: c.slug,
        title: c.title,
        ecosystem: c.ecosystem,
        difficulty: c.difficulty,
        category: c.category,
        version: c.version,
        publicationStatus: c.publication_status,
        isSecurityMission: c.is_security_mission,
        packageValid: check.valid,
        validationErrors: check.errors,
      };
    });

    return NextResponse.json({ total: inventory.length, challenges: inventory });
  } catch (err) {
    return handleApiError(err);
  }
}
