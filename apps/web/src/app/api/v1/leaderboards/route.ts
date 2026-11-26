import { NextResponse } from "next/server";
import { readDb } from "@/lib/store";

export async function GET() {
  const db = readDb();
  const entries = db.users
    .map((u) => ({
      username: u.username,
      displayName: u.displayName,
      totalPoints: u.totalPoints,
      challengesCompleted: u.challengesCompleted,
      securityMissionsCompleted: u.securityMissionsCompleted,
    }))
    .sort((a, b) => b.totalPoints - a.totalPoints || b.challengesCompleted - a.challengesCompleted)
    .slice(0, 50);

  return NextResponse.json({ leaderboard: entries });
}
