import { NextResponse } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { readDb } from "@/lib/store";

export async function GET() {
  const session = await getSessionUser();
  if (!session) {
    return NextResponse.json({ user: null }, { status: 200 });
  }
  const db = readDb();
  const profile = db.users.find((u) => u.id === session.id);
  const unlocks = db.unlocks.filter((u) => u.userId === session.id);
  const achievements = db.achievements.filter((a) => a.userId === session.id);
  const bookmarks = db.bookmarks.filter((b) => b.userId === session.id);

  return NextResponse.json({
    user: {
      ...session,
      bio: profile?.bio ?? "",
      githubUrl: profile?.githubUrl ?? "",
      websiteUrl: profile?.websiteUrl ?? "",
      totalPoints: profile?.totalPoints ?? 0,
      challengesCompleted: profile?.challengesCompleted ?? 0,
      securityMissionsCompleted: profile?.securityMissionsCompleted ?? 0,
    },
    unlocks,
    achievements,
    bookmarks: bookmarks.map((b) => b.challengeSlug),
  });
}
