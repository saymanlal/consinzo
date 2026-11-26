"use client";

import React from "react";
import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { Award, Bookmark, CheckCircle2, Code2, History, Lock } from "lucide-react";
import { Badge, Card } from "@consinzo/ui";

export default function DashboardPage() {
  const { data: meData, isLoading } = useQuery({
    queryKey: ["auth-me"],
    queryFn: async () => (await fetch("/api/v1/auth/me")).json(),
  });

  const { data: subData } = useQuery({
    queryKey: ["my-submissions"],
    queryFn: async () => {
      const res = await fetch("/api/v1/submissions");
      if (!res.ok) return { submissions: [] };
      return res.json();
    },
  });

  if (isLoading) {
    return <div className="mx-auto max-w-5xl p-8 text-xs text-zinc-500">Loading workspace...</div>;
  }

  if (!meData?.user) {
    return (
      <div className="mx-auto max-w-xl px-4 py-16 text-center">
        <Card className="p-8">
          <Lock className="mx-auto h-8 w-8 text-zinc-400" />
          <h1 className="mt-3 text-lg font-semibold text-zinc-950">Authentication Required</h1>
          <p className="mt-1 text-xs text-zinc-600">
            Sign in to inspect your submission history, unlocked solutions, bookmarks, and verified
            progression.
          </p>
          <Link
            href="/auth"
            className="mt-5 inline-flex rounded-md bg-slate-900 px-4 py-2 text-xs font-medium text-white"
          >
            Sign In / Create Account
          </Link>
        </Card>
      </div>
    );
  }

  const user = meData.user;
  const submissions = subData?.submissions ?? [];
  const unlocks = meData.unlocks ?? [];
  const achievements = meData.achievements ?? [];
  const bookmarks: string[] = meData.bookmarks ?? [];

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6 space-y-8">
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-zinc-200 pb-6">
        <div>
          <h1 className="text-2xl font-semibold text-zinc-950">
            Developer Dashboard — {user.displayName}
          </h1>
          <p className="mt-1 font-mono text-xs text-zinc-500">
            @{user.username} · {user.email}
          </p>
        </div>
        <Link
          href="/challenges"
          className="inline-flex items-center gap-2 rounded-md bg-slate-900 px-4 py-2 text-xs font-medium text-white"
        >
          <Code2 className="h-4 w-4" />
          Browse Challenges
        </Link>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Card className="p-4">
          <div className="text-xs text-zinc-500">Verified Score</div>
          <div className="mt-1 font-mono text-2xl font-semibold text-zinc-950">
            {user.totalPoints}
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-zinc-500">Challenges Passed</div>
          <div className="mt-1 font-mono text-2xl font-semibold text-zinc-950">
            {user.challengesCompleted}
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-zinc-500">Security Missions</div>
          <div className="mt-1 font-mono text-2xl font-semibold text-zinc-950">
            {user.securityMissionsCompleted}
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-zinc-500">Verified Badges</div>
          <div className="mt-1 font-mono text-2xl font-semibold text-zinc-950">
            {achievements.length}
          </div>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2 p-6">
          <div className="flex items-center gap-2 text-sm font-semibold text-zinc-950">
            <History className="h-4 w-4" />
            Recent Submissions
          </div>
          <div className="mt-4 space-y-2">
            {submissions.length === 0 ? (
              <p className="text-xs text-zinc-500">
                No submissions yet. Open a challenge in the Codex and click &quot;Submit &amp;
                Evaluate&quot;.
              </p>
            ) : (
              submissions.slice(0, 10).map((s: {
                id: string;
                challengeSlug: string;
                status: string;
                score: number;
                maxPoints: number;
                passed: boolean;
                createdAt: string;
              }) => (
                <div
                  key={s.id}
                  className="flex items-center justify-between rounded border border-zinc-200 px-3 py-2.5 text-xs"
                >
                  <div>
                    <Link
                      href={`/workspace/${s.challengeSlug}`}
                      className="font-mono font-medium text-zinc-950 hover:text-blue-700"
                    >
                      {s.challengeSlug}
                    </Link>
                    <div className="text-[11px] text-zinc-500">
                      {new Date(s.createdAt).toLocaleString()}
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <Badge tone={s.passed ? "green" : "red"}>{s.status}</Badge>
                    <span className="font-mono font-semibold text-zinc-900">
                      {s.score}/{s.maxPoints}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </Card>

        <div className="space-y-6">
          <Card className="p-5">
            <div className="flex items-center gap-2 text-sm font-semibold text-zinc-950">
              <Award className="h-4 w-4 text-amber-600" />
              Verified Achievements
            </div>
            <div className="mt-3 space-y-2 text-xs">
              {achievements.length === 0 ? (
                <p className="text-zinc-500">
                  Pass challenges to earn server-verified achievements.
                </p>
              ) : (
                achievements.map((a: { achievementId: string; awardedAt: string }) => (
                  <div
                    key={a.achievementId}
                    className="flex items-center justify-between rounded border border-zinc-200 p-2.5"
                  >
                    <span className="flex items-center gap-1.5 font-mono text-zinc-900">
                      <CheckCircle2 className="h-3.5 w-3.5 text-emerald-700" />
                      {a.achievementId}
                    </span>
                    <span className="text-[11px] text-zinc-500">
                      {new Date(a.awardedAt).toLocaleDateString()}
                    </span>
                  </div>
                ))
              )}
            </div>
          </Card>

          <Card className="p-5">
            <div className="flex items-center gap-2 text-sm font-semibold text-zinc-950">
              <Bookmark className="h-4 w-4 text-zinc-700" />
              Bookmarked Challenges ({bookmarks.length})
            </div>
            <div className="mt-3 space-y-1.5 text-xs">
              {bookmarks.length === 0 ? (
                <p className="text-zinc-500">No bookmarks saved.</p>
              ) : (
                bookmarks.map((slug) => (
                  <Link
                    key={slug}
                    href={`/workspace/${slug}`}
                    className="block rounded border border-zinc-200 px-2.5 py-1.5 font-mono text-zinc-800 hover:bg-zinc-50"
                  >
                    {slug}
                  </Link>
                ))
              )}
            </div>
          </Card>

          <Card className="p-5">
            <div className="text-sm font-semibold text-zinc-950">
              Solution Unlocks ({unlocks.filter((u: { solutionUnlocked: boolean }) => u.solutionUnlocked).length})
            </div>
            <p className="mt-1 text-xs text-zinc-500">
              Reference solutions unlock strictly after verified test completion.
            </p>
          </Card>
        </div>
      </div>
    </div>
  );
}
