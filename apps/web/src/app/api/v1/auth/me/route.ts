import { NextResponse } from "next/server";
import { getSessionUser, maskPhone, SYNTHETIC_EMAIL_DOMAIN } from "@/lib/auth";
import { getUserDashboardState, getUserProfileById } from "@/lib/data-adapter";

export async function GET() {
  const session = await getSessionUser();
  if (!session) {
    return NextResponse.json({ user: null }, { status: 200 });
  }
  const [profile, state] = await Promise.all([
    getUserProfileById(session.id),
    getUserDashboardState(session.id),
  ]);

  return NextResponse.json({
    user: {
      ...session,
      bio: profile?.bio ?? "",
      githubUrl: profile?.githubUrl ?? "",
      websiteUrl: profile?.websiteUrl ?? "",
      totalPoints: profile?.totalPoints ?? 0,
      challengesCompleted: profile?.challengesCompleted ?? 0,
      securityMissionsCompleted: profile?.securityMissionsCompleted ?? 0,
      // A wallet account has a placeholder address, not a real mailbox: never show it.
      email: session.email.endsWith(SYNTHETIC_EMAIL_DOMAIN) ? "" : session.email,
      walletAddress: profile?.walletAddress ?? null,
      phone: profile?.phone ? maskPhone(profile.phone) : null,
      authProvider: profile?.authProvider ?? "password",
    },
    unlocks: state.unlocks,
    achievements: state.achievements,
    bookmarks: state.bookmarks,
  });
}
