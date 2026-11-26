"use client";

import React, { useMemo } from "react";
import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { ArrowRight, CheckCircle2 } from "lucide-react";
import { Badge, Card } from "@consinzo/ui";
import type { LearningPathSpec } from "@/lib/knowledge";

export function AcademyTracks({ paths }: { paths: readonly LearningPathSpec[] }) {
  const { data: meData } = useQuery<{
    unlocks?: Array<{ challengeSlug: string; passed: boolean }>;
  }>({
    queryKey: ["auth-me"],
    queryFn: async () => (await fetch("/api/v1/auth/me")).json(),
  });

  const passedSlugs = useMemo(
    () => new Set((meData?.unlocks ?? []).filter((u) => u.passed).map((u) => u.challengeSlug)),
    [meData?.unlocks]
  );

  return (
    <div className="mt-8 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
      {paths.map((path) => {
        const completedCount = path.challengeSlugs.filter((s) => passedSlugs.has(s)).length;
        const pct =
          path.challengeSlugs.length > 0
            ? Math.round((completedCount / path.challengeSlugs.length) * 100)
            : 0;
        return (
          <Card key={path.slug} className="p-6 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between gap-2">
                <Badge tone="blue">{path.ecosystemId}</Badge>
                <Badge tone="neutral">{path.difficulty}</Badge>
              </div>
              <h2 className="mt-3 text-lg font-semibold text-zinc-950">{path.title}</h2>
              <p className="mt-2 text-xs leading-relaxed text-zinc-600">{path.description}</p>

              <div className="mt-4">
                <div className="flex items-center justify-between text-[11px] font-mono text-zinc-500">
                  <span>Track Progress</span>
                  <span>
                    {completedCount}/{path.challengeSlugs.length} completed ({pct}%)
                  </span>
                </div>
                <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full bg-zinc-100">
                  <div
                    className="h-full bg-emerald-600 transition-all"
                    style={{ width: `${pct}%` }}
                  />
                </div>
              </div>

              <div className="mt-5 space-y-2">
                <div className="text-xs font-semibold uppercase tracking-wider text-zinc-500">
                  Track Curriculum ({path.challengeSlugs.length} challenges)
                </div>
                {path.challengeSlugs.map((slug, idx) => {
                  const done = passedSlugs.has(slug);
                  return (
                    <Link
                      key={slug}
                      href={`/workspace/${slug}`}
                      className="flex items-center justify-between rounded border border-zinc-200 px-3 py-2 text-xs hover:bg-zinc-50"
                    >
                      <span className="flex items-center gap-2 font-mono text-zinc-800 truncate">
                        {done && <CheckCircle2 className="h-3.5 w-3.5 shrink-0 text-emerald-700" />}
                        0{idx + 1}. {slug}
                      </span>
                      <ArrowRight className="h-3.5 w-3.5 shrink-0 text-zinc-400" />
                    </Link>
                  );
                })}
              </div>
            </div>
          </Card>
        );
      })}
    </div>
  );
}
