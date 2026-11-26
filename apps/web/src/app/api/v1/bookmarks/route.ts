import { NextResponse } from "next/server";
import { z } from "zod";
import { requireSessionUser } from "@/lib/auth";
import { handleApiError } from "@/lib/http";
import { readDb, writeDb } from "@/lib/store";

const BookmarkSchema = z.object({
  challengeSlug: z.string().regex(/^[a-z0-9-]+$/),
});

export async function GET() {
  try {
    const user = await requireSessionUser();
    const db = readDb();
    const slugs = db.bookmarks
      .filter((b) => b.userId === user.id)
      .map((b) => b.challengeSlug);
    return NextResponse.json({ bookmarks: slugs });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(req: Request) {
  try {
    const user = await requireSessionUser();
    const { challengeSlug } = BookmarkSchema.parse(await req.json());
    const db = readDb();
    const existingIdx = db.bookmarks.findIndex(
      (b) => b.userId === user.id && b.challengeSlug === challengeSlug
    );
    let bookmarked = false;
    if (existingIdx >= 0) {
      db.bookmarks.splice(existingIdx, 1);
    } else {
      db.bookmarks.push({
        userId: user.id,
        challengeSlug,
        createdAt: new Date().toISOString(),
      });
      bookmarked = true;
    }
    writeDb(db);
    return NextResponse.json({ bookmarked, challengeSlug });
  } catch (err) {
    return handleApiError(err);
  }
}
