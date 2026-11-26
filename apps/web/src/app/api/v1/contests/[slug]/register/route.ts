import { NextResponse } from "next/server";
import { ConsinzoError } from "@consinzo/shared";
import { requireSessionUser } from "@/lib/auth";
import { handleApiError } from "@/lib/http";
import { readDb, writeDb } from "@/lib/store";

export async function POST(
  _req: Request,
  context: { params: Promise<{ slug: string }> }
) {
  try {
    const user = await requireSessionUser();
    const { slug } = await context.params;
    const db = readDb();
    const contest = db.contests.find((c) => c.slug === slug);
    if (!contest) {
      throw new ConsinzoError("NOT_FOUND", "Competition not found.", 404);
    }
    if (!contest.registeredUserIds.includes(user.id)) {
      contest.registeredUserIds.push(user.id);
      writeDb(db);
    }
    return NextResponse.json({
      registered: true,
      participantCount: contest.registeredUserIds.length,
    });
  } catch (err) {
    return handleApiError(err);
  }
}
