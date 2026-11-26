import { NextResponse } from "next/server";
import { z } from "zod";
import { requireSessionUser } from "@/lib/auth";
import { getUserDashboardState, toggleBookmarkForUser } from "@/lib/data-adapter";
import { handleApiError } from "@/lib/http";

const BookmarkSchema = z.object({
  challengeSlug: z.string().regex(/^[a-z0-9-]+$/),
});

export async function GET() {
  try {
    const user = await requireSessionUser();
    const state = await getUserDashboardState(user.id);
    return NextResponse.json({ bookmarks: state.bookmarks });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(req: Request) {
  try {
    const user = await requireSessionUser();
    const { challengeSlug } = BookmarkSchema.parse(await req.json());
    const bookmarked = await toggleBookmarkForUser(user.id, challengeSlug);
    return NextResponse.json({ bookmarked, challengeSlug });
  } catch (err) {
    return handleApiError(err);
  }
}
