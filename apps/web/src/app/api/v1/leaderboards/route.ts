import { NextResponse } from "next/server";
import { getLeaderboardEntries, type LeaderboardCategory } from "@/lib/data-adapter";

const VALID_CATEGORIES = new Set<LeaderboardCategory>([
  "overall",
  "security",
  "coding",
  "weekly",
  "monthly",
]);

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const rawCategory = (searchParams.get("category") ?? "overall") as LeaderboardCategory;
  const category = VALID_CATEGORIES.has(rawCategory) ? rawCategory : "overall";
  const leaderboard = await getLeaderboardEntries(category);
  return NextResponse.json({ category, leaderboard });
}
