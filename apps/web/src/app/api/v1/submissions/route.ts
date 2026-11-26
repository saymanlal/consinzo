import { NextResponse } from "next/server";
import { SnapshotSubmissionSchema } from "@consinzo/validators";
import { requireSessionUser } from "@/lib/auth";
import { executeAndScoreSubmission } from "@/lib/evaluation-service";
import { handleApiError } from "@/lib/http";
import { readDb } from "@/lib/store";

export async function GET(req: Request) {
  try {
    const user = await requireSessionUser();
    const { searchParams } = new URL(req.url);
    const challengeSlug = searchParams.get("challengeSlug");
    const db = readDb();

    let items = db.submissions.filter((s) => s.userId === user.id);
    if (challengeSlug) {
      items = items.filter((s) => s.challengeSlug === challengeSlug);
    }

    return NextResponse.json({
      submissions: items.slice(0, 50),
    });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(req: Request) {
  try {
    const user = await requireSessionUser();
    const body = SnapshotSubmissionSchema.parse(await req.json());
    const submission = await executeAndScoreSubmission({
      userId: user.id,
      challengeSlug: body.challengeSlug,
      mode: body.mode,
      files: body.files,
    });
    return NextResponse.json({ submission }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
