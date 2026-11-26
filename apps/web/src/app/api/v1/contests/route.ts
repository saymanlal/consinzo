import { NextResponse } from "next/server";
import { z } from "zod";
import { requireAdminRole } from "@/lib/auth";
import { handleApiError } from "@/lib/http";
import { readDb, writeDb } from "@/lib/store";

const CreateContestSchema = z.object({
  slug: z.string().regex(/^[a-z0-9-]+$/),
  title: z.string().min(4).max(120),
  description: z.string().min(10).max(1000),
  contestType: z.enum(["coding", "security", "university", "sponsored"]),
  visibility: z.enum(["public", "private"]).default("public"),
  startsAt: z.string().datetime(),
  endsAt: z.string().datetime(),
  challengeSlugs: z.array(z.string()).min(1),
});

export async function GET() {
  const db = readDb();
  return NextResponse.json({
    contests: db.contests.map((c) => ({
      ...c,
      participantCount: c.registeredUserIds.length,
    })),
  });
}

export async function POST(req: Request) {
  try {
    const organizer = await requireAdminRole([
      "competition_organizer",
      "platform_admin",
      "super_admin",
    ]);
    const body = CreateContestSchema.parse(await req.json());
    const db = readDb();
    const contest = {
      ...body,
      organizerId: organizer.id,
      registeredUserIds: [],
    };
    db.contests.push(contest);
    writeDb(db);
    return NextResponse.json({ contest }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
