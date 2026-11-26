import { NextResponse } from "next/server";
import { SnapshotSubmissionSchema } from "@consinzo/validators";
import { requireSessionUser } from "@/lib/auth";
import { listUserSubmissions } from "@/lib/data-adapter";
import { executeAndScoreSubmission } from "@/lib/evaluation-service";
import { handleApiError } from "@/lib/http";

export async function GET(req: Request) {
  try {
    const user = await requireSessionUser();
    const { searchParams } = new URL(req.url);
    const challengeSlug = searchParams.get("challengeSlug") ?? undefined;
    const submissions = await listUserSubmissions(user.id, challengeSlug);
    return NextResponse.json({ submissions });
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
