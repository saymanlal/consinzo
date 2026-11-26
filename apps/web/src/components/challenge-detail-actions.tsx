"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Bookmark,
  CheckCircle2,
  Code2,
  KeyRound,
  Lightbulb,
  Lock,
  ArrowRight,
} from "lucide-react";
import { Badge, Button, Card } from "@consinzo/ui";

interface HintItem {
  order: number;
  title: string;
  content: string;
}

export function ChallengeDetailActions({
  slug,
  maxPoints,
  unlockPolicy,
  hints,
}: {
  slug: string;
  maxPoints: number;
  unlockPolicy: string;
  hints: HintItem[];
}) {
  const queryClient = useQueryClient();
  const [bookmarkMsg, setBookmarkMsg] = useState<string | null>(null);
  const [revealedHints, setRevealedHints] = useState<number[]>([]);
  const [solutionState, setSolutionState] = useState<{
    open: boolean;
    loading: boolean;
    error?: string;
    data?: { files: Array<{ path: string; content: string }>; explanationMarkdown: string };
  }>({ open: false, loading: false });

  const { data: meData } = useQuery<{
    user: { id: string } | null;
    bookmarks?: string[];
    unlocks?: Array<{
      challengeSlug: string;
      passed: boolean;
      attempts: number;
      bestScore: number;
      solutionUnlocked: boolean;
    }>;
  }>({
    queryKey: ["auth-me"],
    queryFn: async () => (await fetch("/api/v1/auth/me")).json(),
  });

  const isBookmarked = Boolean(meData?.bookmarks?.includes(slug));
  const progress = meData?.unlocks?.find((u) => u.challengeSlug === slug);

  async function handleToggleBookmark() {
    setBookmarkMsg(null);
    const res = await fetch("/api/v1/bookmarks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ challengeSlug: slug }),
    });
    if (res.status === 401) {
      setBookmarkMsg("Sign in to save bookmarks.");
      return;
    }
    if (res.ok) {
      await queryClient.invalidateQueries({ queryKey: ["auth-me"] });
    }
  }

  async function handleViewSolution() {
    if (solutionState.open) {
      setSolutionState((s) => ({ ...s, open: false }));
      return;
    }
    setSolutionState({ open: true, loading: true });
    try {
      const res = await fetch(`/api/v1/challenges/${slug}/solution`);
      const json = await res.json();
      if (!res.ok) {
        setSolutionState({
          open: true,
          loading: false,
          error: json?.error?.message ?? "Reference solution is locked.",
        });
        return;
      }
      setSolutionState({ open: true, loading: false, data: json });
    } catch {
      setSolutionState({
        open: true,
        loading: false,
        error: "Network error checking solution unlock status.",
      });
    }
  }

  return (
    <div className="space-y-4">
      <Card className="p-5 space-y-3">
        <div className="flex items-center justify-between text-xs">
          <span className="font-medium text-zinc-500">Your Progress</span>
          {progress ? (
            <Badge tone={progress.passed ? "green" : "amber"}>
              {progress.passed ? (
                <span className="inline-flex items-center gap-1">
                  <CheckCircle2 className="h-3 w-3" />
                  Passed ({progress.bestScore}/{maxPoints})
                </span>
              ) : (
                `${progress.attempts} attempt(s) · Best ${progress.bestScore}/${maxPoints}`
              )}
            </Badge>
          ) : (
            <Badge tone="neutral">Not started</Badge>
          )}
        </div>

        <Link
          href={`/workspace/${slug}`}
          className="flex w-full items-center justify-center gap-2 rounded-md bg-slate-900 px-4 py-2.5 text-sm font-medium text-white hover:bg-slate-800"
        >
          <Code2 className="h-4 w-4" />
          Start Coding
          <ArrowRight className="h-4 w-4" />
        </Link>

        <div className="grid grid-cols-2 gap-2">
          <Button variant="outline" size="sm" onClick={handleToggleBookmark}>
            <Bookmark className={`h-3.5 w-3.5 ${isBookmarked ? "fill-zinc-900" : ""}`} />
            {isBookmarked ? "Bookmarked" : "Bookmark"}
          </Button>
          <Button variant="outline" size="sm" onClick={handleViewSolution}>
            <KeyRound className="h-3.5 w-3.5" />
            Solution
          </Button>
        </div>

        {bookmarkMsg && (
          <p className="text-[11px] text-amber-800">
            {bookmarkMsg}{" "}
            <Link href="/auth" className="underline font-medium">
              Sign in →
            </Link>
          </p>
        )}

        {solutionState.open && (
          <div className="rounded border border-zinc-200 bg-zinc-50 p-3 text-xs space-y-2">
            {solutionState.loading && <p className="text-zinc-500">Checking unlock policy...</p>}
            {solutionState.error && (
              <div className="flex items-start gap-2 text-zinc-700">
                <Lock className="h-3.5 w-3.5 shrink-0 mt-0.5 text-zinc-500" />
                <div>
                  <p className="font-medium text-zinc-900">Protected ({unlockPolicy})</p>
                  <p className="mt-0.5 text-zinc-600">{solutionState.error}</p>
                </div>
              </div>
            )}
            {solutionState.data && (
              <div className="space-y-2">
                <p className="font-medium text-emerald-800">Reference Solution Unlocked</p>
                <p className="text-zinc-700">{solutionState.data.explanationMarkdown}</p>
                {solutionState.data.files.map((f) => (
                  <pre
                    key={f.path}
                    className="overflow-x-auto rounded bg-zinc-950 p-2.5 font-mono text-[11px] text-zinc-200"
                  >
                    {f.content}
                  </pre>
                ))}
              </div>
            )}
          </div>
        )}
      </Card>

      {hints.length > 0 && (
        <Card className="p-5 space-y-3 text-xs">
          <h3 className="font-semibold text-zinc-950 flex items-center gap-1.5">
            <Lightbulb className="h-3.5 w-3.5 text-amber-600" />
            Progressive Hints ({hints.length})
          </h3>
          <div className="space-y-2">
            {hints.map((h) => {
              const shown = revealedHints.includes(h.order);
              return (
                <div key={h.order} className="rounded border border-zinc-200 p-2.5">
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-medium text-zinc-800">
                      {h.order}. {h.title}
                    </span>
                    {!shown && (
                      <button
                        type="button"
                        onClick={() => setRevealedHints((p) => [...p, h.order])}
                        className="text-blue-700 hover:underline cursor-pointer"
                      >
                        Reveal
                      </button>
                    )}
                  </div>
                  {shown && <p className="mt-1.5 text-zinc-600">{h.content}</p>}
                </div>
              );
            })}
          </div>
        </Card>
      )}
    </div>
  );
}
