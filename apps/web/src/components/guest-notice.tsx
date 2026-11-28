"use client";

import React from "react";
import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { UserRound } from "lucide-react";
import { DIFFICULTY_META } from "@/lib/difficulty";
import { GUEST_LIMITS } from "@/lib/guest-limits";

/** Shown above the catalogue to visitors without an account: what they can do, and the limits. */
export function GuestNotice() {
  const { data, isLoading } = useQuery<{ user: { id: string } | null }>({
    queryKey: ["auth-me"],
    queryFn: async () => {
      const res = await fetch("/api/v1/auth/me");
      return res.ok ? res.json() : { user: null };
    },
  });
  if (isLoading || data?.user) return null;

  return (
    <div className="mb-5 flex flex-wrap items-center justify-between gap-3 rounded-lg border border-cyan-200 bg-cyan-50 px-4 py-3 text-xs text-cyan-950">
      <p className="flex min-w-0 items-start gap-2">
        <UserRound className="mt-0.5 h-4 w-4 shrink-0" />
        <span>
          <strong>You are browsing as a guest.</strong> Open any{" "}
          {GUEST_LIMITS.TIERS.map((t) => DIFFICULTY_META[t].label).join(", ")} challenge and run
          its public tests, up to {GUEST_LIMITS.RUNS_PER_HOUR} runs an hour. An account adds
          hidden-suite scoring, points, badges, solutions and every difficulty.
        </span>
      </p>
      <Link
        href="/auth?mode=register&next=/challenges"
        className="shrink-0 rounded-md bg-slate-900 px-3 py-1.5 font-medium text-white hover:bg-slate-800"
      >
        Create free account
      </Link>
    </div>
  );
}
