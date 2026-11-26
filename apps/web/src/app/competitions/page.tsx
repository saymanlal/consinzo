"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Calendar, Plus, Trophy, Users } from "lucide-react";
import { Badge, Button, Card, Input } from "@consinzo/ui";

interface Contest {
  slug: string;
  title: string;
  description: string;
  contestType: string;
  visibility: string;
  startsAt: string;
  endsAt: string;
  challengeSlugs: string[];
  participantCount: number;
}

interface ContestDetails {
  contest: Contest;
  teams: Array<{
    id: string;
    name: string;
    members: Array<{ username: string; displayName: string }>;
  }>;
  standings: Array<{
    username: string;
    displayName: string;
    totalScore: number;
    lastAcceptedAt: string;
  }>;
}

interface LeaderboardEntry {
  username: string;
  displayName: string;
  totalPoints: number;
  challengesCompleted: number;
  securityMissionsCompleted: number;
}

export default function CompetitionsPage() {
  const queryClient = useQueryClient();
  const [lbCategory, setLbCategory] = useState<
    "overall" | "security" | "coding" | "weekly" | "monthly"
  >("overall");
  const [selectedSlug, setSelectedSlug] = useState<string>("evm-security-sprint-01");
  const [teamName, setTeamName] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const { data: contestsData } = useQuery<{ contests: Contest[] }>({
    queryKey: ["contests"],
    queryFn: async () => (await fetch("/api/v1/contests")).json(),
  });

  const { data: lbData } = useQuery<{ leaderboard: LeaderboardEntry[] }>({
    queryKey: ["leaderboard", lbCategory],
    queryFn: async () => (await fetch(`/api/v1/leaderboards?category=${lbCategory}`)).json(),
  });

  const { data: detailsData } = useQuery<ContestDetails | null>({
    queryKey: ["contest-details", selectedSlug],
    queryFn: async () => {
      if (!selectedSlug) return null;
      const res = await fetch(`/api/v1/contests/${selectedSlug}/teams`);
      if (!res.ok) return null;
      return res.json();
    },
    enabled: Boolean(selectedSlug),
  });

  async function register(slug: string) {
    setErr(null);
    setMsg(null);
    const res = await fetch(`/api/v1/contests/${slug}/register`, { method: "POST" });
    const json = await res.json();
    if (!res.ok) {
      setErr(json?.error?.message ?? "Sign in required to register.");
      return;
    }
    setMsg("Registered for competition.");
    await queryClient.invalidateQueries({ queryKey: ["contests"] });
  }

  async function createTeam(e: React.FormEvent) {
    e.preventDefault();
    if (!selectedSlug || !teamName.trim()) return;
    setErr(null);
    setMsg(null);
    const res = await fetch(`/api/v1/contests/${selectedSlug}/teams`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "create", name: teamName.trim() }),
    });
    const json = await res.json();
    if (!res.ok) {
      setErr(json?.error?.message ?? "Failed to create team (sign in required).");
      return;
    }
    setTeamName("");
    setMsg(`Created team "${json.team.name}".`);
    await queryClient.invalidateQueries({ queryKey: ["contest-details", selectedSlug] });
    await queryClient.invalidateQueries({ queryKey: ["contests"] });
  }

  async function joinTeam(teamId: string) {
    setErr(null);
    setMsg(null);
    const res = await fetch(`/api/v1/contests/${selectedSlug}/teams`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "join", teamId }),
    });
    const json = await res.json();
    if (!res.ok) {
      setErr(json?.error?.message ?? "Failed to join team (sign in required).");
      return;
    }
    setMsg(`Joined team "${json.team.name}".`);
    await queryClient.invalidateQueries({ queryKey: ["contest-details", selectedSlug] });
    await queryClient.invalidateQueries({ queryKey: ["contests"] });
  }

  const contests = contestsData?.contests ?? [];
  const leaderboard = lbData?.leaderboard ?? [];

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6 space-y-8">
      <div className="border-b border-zinc-200 pb-6">
        <div className="inline-flex items-center gap-1.5 text-xs font-mono uppercase tracking-wider text-zinc-500">
          <Trophy className="h-4 w-4 text-amber-600" />
          Competitions, Teams &amp; Leaderboards
        </div>
        <h1 className="mt-2 text-2xl font-semibold text-zinc-950">
          Engineering Sprints &amp; Security Contests
        </h1>
        <p className="mt-1 text-sm text-zinc-600 max-w-3xl">
          Time-bounded smart contract engineering and security tournaments backed by server-verified
          timestamps, team rosters, and immutable submission scores.
        </p>
      </div>

      {err && (
        <div className="rounded border border-red-200 bg-red-50 px-4 py-2.5 text-xs text-red-800">
          {err}
        </div>
      )}
      {msg && (
        <div className="rounded border border-emerald-200 bg-emerald-50 px-4 py-2.5 text-xs text-emerald-800">
          {msg}
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2 space-y-6">
          <div className="space-y-4">
            <h2 className="text-base font-semibold text-zinc-950">Scheduled Contests</h2>
            {contests.map((c) => (
              <Card key={c.slug} className="p-5 space-y-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <Badge tone="blue">{c.contestType}</Badge>
                    <Badge tone="neutral">{c.visibility}</Badge>
                  </div>
                  <span className="inline-flex items-center gap-1 text-xs text-zinc-500">
                    <Users className="h-3.5 w-3.5" />
                    {c.participantCount} registered
                  </span>
                </div>

                <div>
                  <h3 className="text-lg font-semibold text-zinc-950">{c.title}</h3>
                  <p className="mt-1 text-xs text-zinc-600">{c.description}</p>
                </div>

                <div className="flex flex-wrap gap-2">
                  {c.challengeSlugs.map((slug) => (
                    <Link
                      key={slug}
                      href={`/workspace/${slug}`}
                      className="rounded border border-zinc-200 bg-zinc-50 px-2.5 py-1 font-mono text-xs text-zinc-800 hover:bg-zinc-100"
                    >
                      {slug}
                    </Link>
                  ))}
                </div>

                <div className="flex flex-wrap items-center justify-between gap-3 border-t border-zinc-100 pt-3">
                  <span className="inline-flex items-center gap-1.5 font-mono text-[11px] text-zinc-500">
                    <Calendar className="h-3.5 w-3.5" />
                    {new Date(c.startsAt).toLocaleDateString()} —{" "}
                    {new Date(c.endsAt).toLocaleDateString()}
                  </span>
                  <div className="flex gap-2">
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => setSelectedSlug(c.slug)}
                    >
                      Teams &amp; Standings
                    </Button>
                    <Button size="sm" onClick={() => register(c.slug)}>
                      Register
                    </Button>
                  </div>
                </div>
              </Card>
            ))}
          </div>

          {/* Active Contest Teams & Live Standings */}
          {detailsData && (
            <Card className="p-5 space-y-5">
              <div className="flex flex-wrap items-center justify-between gap-2 border-b border-zinc-100 pb-3">
                <div>
                  <h3 className="text-sm font-semibold text-zinc-950">
                    {detailsData.contest.title} — Teams &amp; Standings
                  </h3>
                  <p className="text-xs text-zinc-500">
                    Create or join a team and track live contest scores.
                  </p>
                </div>
              </div>

              <form onSubmit={createTeam} className="flex flex-wrap gap-2">
                <Input
                  value={teamName}
                  onChange={(e) => setTeamName(e.target.value)}
                  placeholder="New team name (2-40 chars)..."
                  className="max-w-xs"
                />
                <Button type="submit" size="sm">
                  <Plus className="h-3.5 w-3.5" />
                  Create Team
                </Button>
              </form>

              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <h4 className="text-xs font-semibold uppercase tracking-wider text-zinc-500">
                    Registered Teams ({detailsData.teams.length})
                  </h4>
                  {detailsData.teams.length === 0 ? (
                    <p className="text-xs text-zinc-500">No teams formed yet.</p>
                  ) : (
                    detailsData.teams.map((t) => (
                      <div
                        key={t.id}
                        className="flex items-center justify-between rounded border border-zinc-200 p-2.5 text-xs"
                      >
                        <div>
                          <div className="font-semibold text-zinc-900">{t.name}</div>
                          <div className="font-mono text-[11px] text-zinc-500">
                            {t.members.map((m) => `@${m.username}`).join(", ")}
                          </div>
                        </div>
                        <Button size="sm" variant="outline" onClick={() => joinTeam(t.id)}>
                          Join
                        </Button>
                      </div>
                    ))
                  )}
                </div>

                <div className="space-y-2">
                  <h4 className="text-xs font-semibold uppercase tracking-wider text-zinc-500">
                    Contest Leaderboard
                  </h4>
                  {detailsData.standings.length === 0 ? (
                    <p className="text-xs text-zinc-500">
                      No contest submissions scored yet.
                    </p>
                  ) : (
                    detailsData.standings.map((s, idx) => (
                      <div
                        key={s.username}
                        className="flex items-center justify-between rounded border border-zinc-200 px-3 py-2 text-xs"
                      >
                        <span className="font-mono">
                          #{idx + 1}{" "}
                          <Link href={`/u/${s.username}`} className="hover:underline text-zinc-900">
                            @{s.username}
                          </Link>
                        </span>
                        <span className="font-mono font-semibold text-zinc-950">
                          {s.totalScore} pts
                        </span>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </Card>
          )}
        </div>

        <Card className="p-5 h-fit space-y-4">
          <div>
            <h2 className="text-sm font-semibold text-zinc-950">Verified Developer Standings</h2>
            <p className="mt-1 text-xs text-zinc-500">
              Ranked strictly by server-verified evaluation scores.
            </p>
          </div>

          <div className="flex flex-wrap gap-1">
            {(["overall", "security", "coding", "weekly", "monthly"] as const).map((cat) => (
              <button
                key={cat}
                type="button"
                onClick={() => setLbCategory(cat)}
                className={`rounded px-2.5 py-1 text-[11px] font-medium capitalize cursor-pointer ${
                  lbCategory === cat
                    ? "bg-slate-900 text-white"
                    : "bg-zinc-100 text-zinc-600 hover:bg-zinc-200"
                }`}
              >
                {cat}
              </button>
            ))}
          </div>

          <div className="space-y-2">
            {leaderboard.length === 0 ? (
              <p className="text-xs text-zinc-500 py-4">
                No verified completions recorded yet. Be the first developer to pass a challenge.
              </p>
            ) : (
              leaderboard.map((entry, idx) => (
                <Link
                  key={entry.username}
                  href={`/u/${entry.username}`}
                  className="flex items-center justify-between rounded border border-zinc-200 px-3 py-2 text-xs hover:bg-zinc-50"
                >
                  <div className="flex items-center gap-2.5">
                    <span className="font-mono text-zinc-400">#{idx + 1}</span>
                    <div>
                      <div className="font-medium text-zinc-900">{entry.displayName}</div>
                      <div className="font-mono text-[11px] text-zinc-500">@{entry.username}</div>
                    </div>
                  </div>
                  <div className="text-right font-mono">
                    <div className="font-semibold text-zinc-950">{entry.totalPoints} pts</div>
                    <div className="text-[11px] text-zinc-500">
                      {lbCategory === "security"
                        ? `${entry.securityMissionsCompleted} missions`
                        : `${entry.challengesCompleted} solved`}
                    </div>
                  </div>
                </Link>
              ))
            )}
          </div>
        </Card>
      </div>
    </div>
  );
}
