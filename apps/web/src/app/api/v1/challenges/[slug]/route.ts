import { NextResponse } from "next/server";
import { getChallengeBySlug } from "@/lib/challenges";

export async function GET(
  _req: Request,
  context: { params: Promise<{ slug: string }> }
) {
  const { slug } = await context.params;
  const outcome = getChallengeBySlug(slug);

  if (outcome.status === "error") {
    if (outcome.kind === "storage_error") {
      return NextResponse.json(
        { error: { code: "STORAGE_UNAVAILABLE", message: outcome.message } },
        { status: 503 }
      );
    }
    if (outcome.kind === "incomplete") {
      return NextResponse.json(
        { error: { code: "CHALLENGE_INCOMPLETE", message: outcome.message } },
        { status: 422 }
      );
    }
    return NextResponse.json(
      { error: { code: "NOT_FOUND", message: outcome.message } },
      { status: 404 }
    );
  }

  return NextResponse.json(outcome.data);
}
