import { NextResponse } from "next/server";
import { getPublishedChallengesResult } from "@/lib/challenges";
import { normalizeDifficulty } from "@/lib/difficulty";

export async function GET(req: Request) {
  const result = getPublishedChallengesResult();
  if (result.status === "error") {
    return NextResponse.json(
      { error: { code: "STORAGE_UNAVAILABLE", message: result.message } },
      { status: 503 }
    );
  }

  const { searchParams } = new URL(req.url);
  const ecosystem = searchParams.get("ecosystem");
  const difficulty = searchParams.get("difficulty");
  const category = searchParams.get("category");
  const securityOnly = searchParams.get("security") === "true";
  const q = searchParams.get("q")?.trim().toLowerCase() ?? "";

  let items = result.challenges;

  if (ecosystem && ecosystem !== "all") {
    items = items.filter((c) => c.ecosystem === ecosystem);
  }
  if (difficulty && difficulty !== "all") {
    items = items.filter((c) => c.difficulty === normalizeDifficulty(difficulty));
  }
  if (category && category !== "all") {
    items = items.filter((c) => c.category === category);
  }
  if (securityOnly) {
    items = items.filter((c) => c.is_security_mission);
  }
  if (q) {
    items = items.filter(
      (c) =>
        c.slug.toLowerCase().includes(q) ||
        c.title.toLowerCase().includes(q) ||
        c.description.toLowerCase().includes(q) ||
        c.tags.some((t) => t.toLowerCase().includes(q))
    );
  }

  return NextResponse.json({
    total: items.length,
    challenges: items,
  });
}
