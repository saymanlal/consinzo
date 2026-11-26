import { NextResponse } from "next/server";
import { z } from "zod";
import { requireSessionUser } from "@/lib/auth";
import {
  createContestTeam,
  getContestDetailsAndStandings,
  joinContestTeam,
} from "@/lib/data-adapter";
import { handleApiError } from "@/lib/http";

const TeamActionSchema = z.discriminatedUnion("action", [
  z.object({
    action: z.literal("create"),
    name: z.string().min(2).max(40),
  }),
  z.object({
    action: z.literal("join"),
    teamId: z.string().uuid(),
  }),
]);

export async function GET(
  _req: Request,
  context: { params: Promise<{ slug: string }> }
) {
  try {
    const { slug } = await context.params;
    const details = await getContestDetailsAndStandings(slug);
    if (!details) {
      return NextResponse.json(
        { error: { code: "NOT_FOUND", message: "Competition not found." } },
        { status: 404 }
      );
    }
    return NextResponse.json(details);
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(
  req: Request,
  context: { params: Promise<{ slug: string }> }
) {
  try {
    const user = await requireSessionUser();
    const { slug } = await context.params;
    const body = TeamActionSchema.parse(await req.json());

    if (body.action === "create") {
      const team = await createContestTeam(slug, user.id, body.name.trim());
      return NextResponse.json({ team }, { status: 201 });
    }
    const team = await joinContestTeam(slug, user.id, body.teamId);
    return NextResponse.json({ team });
  } catch (err) {
    return handleApiError(err);
  }
}
