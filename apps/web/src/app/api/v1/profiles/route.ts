import { NextResponse } from "next/server";
import { z } from "zod";
import { requireSessionUser } from "@/lib/auth";
import { handleApiError } from "@/lib/http";
import { readDb, writeDb } from "@/lib/store";

const ProfileUpdateSchema = z.object({
  displayName: z.string().min(2).max(60).optional(),
  bio: z.string().max(400).optional(),
  githubUrl: z.string().url().or(z.literal("")).optional(),
  websiteUrl: z.string().url().or(z.literal("")).optional(),
});

export async function GET() {
  try {
    const session = await requireSessionUser();
    const db = readDb();
    const user = db.users.find((u) => u.id === session.id);
    if (!user) return NextResponse.json({ profile: null }, { status: 404 });
    return NextResponse.json({
      profile: {
        username: user.username,
        displayName: user.displayName,
        bio: user.bio,
        githubUrl: user.githubUrl,
        websiteUrl: user.websiteUrl,
        totalPoints: user.totalPoints,
        challengesCompleted: user.challengesCompleted,
        securityMissionsCompleted: user.securityMissionsCompleted,
      },
    });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function PATCH(req: Request) {
  try {
    const session = await requireSessionUser();
    const updates = ProfileUpdateSchema.parse(await req.json());
    const db = readDb();
    const user = db.users.find((u) => u.id === session.id);
    if (!user) return NextResponse.json({ error: { code: "NOT_FOUND", message: "User not found" } }, { status: 404 });

    // Notice: totalPoints, roles, challengesCompleted are NEVER updatable from client PATCH
    if (updates.displayName !== undefined) user.displayName = updates.displayName;
    if (updates.bio !== undefined) user.bio = updates.bio;
    if (updates.githubUrl !== undefined) user.githubUrl = updates.githubUrl;
    if (updates.websiteUrl !== undefined) user.websiteUrl = updates.websiteUrl;

    writeDb(db);
    return NextResponse.json({
      profile: {
        username: user.username,
        displayName: user.displayName,
        bio: user.bio,
        githubUrl: user.githubUrl,
        websiteUrl: user.websiteUrl,
        totalPoints: user.totalPoints,
        challengesCompleted: user.challengesCompleted,
        securityMissionsCompleted: user.securityMissionsCompleted,
      },
    });
  } catch (err) {
    return handleApiError(err);
  }
}
