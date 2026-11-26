import { NextResponse } from "next/server";
import { z } from "zod";
import { requireSessionUser } from "@/lib/auth";
import { getUserProfileById, updateUserProfileSafe } from "@/lib/data-adapter";
import { handleApiError } from "@/lib/http";

const ProfileUpdateSchema = z.object({
  displayName: z.string().min(2).max(60).optional(),
  bio: z.string().max(400).optional(),
  githubUrl: z.string().url().or(z.literal("")).optional(),
  websiteUrl: z.string().url().or(z.literal("")).optional(),
});

export async function GET() {
  try {
    const session = await requireSessionUser();
    const profile = await getUserProfileById(session.id);
    if (!profile) return NextResponse.json({ profile: null }, { status: 404 });
    return NextResponse.json({ profile });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function PATCH(req: Request) {
  try {
    const session = await requireSessionUser();
    const updates = ProfileUpdateSchema.parse(await req.json());
    // Notice: totalPoints, roles, challengesCompleted are NEVER updatable from client PATCH
    const profile = await updateUserProfileSafe(session.id, updates);
    if (!profile) {
      return NextResponse.json(
        { error: { code: "NOT_FOUND", message: "User not found" } },
        { status: 404 }
      );
    }
    return NextResponse.json({ profile });
  } catch (err) {
    return handleApiError(err);
  }
}
