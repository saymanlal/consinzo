import { NextResponse } from "next/server";
import { getPublicChallengeBySlug } from "@/lib/challenges";

export async function GET(
  _req: Request,
  context: { params: Promise<{ slug: string }> }
) {
  const { slug } = await context.params;
  const challenge = getPublicChallengeBySlug(slug);
  if (!challenge) {
    return NextResponse.json(
      { error: { code: "NOT_FOUND", message: "Challenge not found." } },
      { status: 404 }
    );
  }
  return NextResponse.json(challenge);
}
