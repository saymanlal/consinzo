import { NextResponse } from "next/server";
import { z } from "zod";
import { requireAdminRole } from "@/lib/auth";
import { createContestRecord, listContestsWithCounts } from "@/lib/data-adapter";
import { handleApiError } from "@/lib/http";

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
  const contests = await listContestsWithCounts();
  return NextResponse.json({ contests });
}

export async function POST(req: Request) {
  try {
    const organizer = await requireAdminRole([
      "competition_organizer",
      "platform_admin",
      "super_admin",
    ]);
    const body = CreateContestSchema.parse(await req.json());
    const contest = await createContestRecord({
      ...body,
      organizerId: organizer.id,
      registeredUserIds: [],
    });
    return NextResponse.json({ contest }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
