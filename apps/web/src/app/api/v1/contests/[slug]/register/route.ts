import { NextResponse } from "next/server";
import { requireSessionUser } from "@/lib/auth";
import { registerUserForContest } from "@/lib/data-adapter";
import { handleApiError } from "@/lib/http";

export async function POST(
  _req: Request,
  context: { params: Promise<{ slug: string }> }
) {
  try {
    const user = await requireSessionUser();
    const { slug } = await context.params;
    const result = await registerUserForContest(slug, user.id);
    return NextResponse.json(result);
  } catch (err) {
    return handleApiError(err);
  }
}
