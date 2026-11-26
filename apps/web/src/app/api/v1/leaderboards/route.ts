import { NextResponse } from "next/server";
import { getLeaderboardEntries } from "@/lib/data-adapter";

export async function GET() {
  const leaderboard = await getLeaderboardEntries();
  return NextResponse.json({ leaderboard });
}
