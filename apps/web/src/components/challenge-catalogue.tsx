"use client";

import React, { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Bookmark, CheckCircle2, Code2, Search, Shield } from "lucide-react";
import type { ChallengeManifest } from "@consinzo/challenge-spec";
import { CHALLENGE_CATEGORIES } from "@consinzo/shared";
import { ECOSYSTEM_REGISTRY } from "@consinzo/ecosystem-registry";
import { Badge, Card, Input } from "@consinzo/ui";

import { DifficultyBadge } from "@/components/difficulty-badge";
import {
  DIFFICULTY_META,
  DIFFICULTY_TIERS,
  normalizeDifficulty,
  type DifficultyTier,
} from "@/lib/difficulty";

type SortKey = "recommended" | "easiest" | "hardest" | "points" | "title";
type KindFilter = "all" | "engineering" | "security";

const SELECT =
  "h-10 w-full rounded-md border border-zinc-300 bg-white px-3 text-sm text-zinc-800 focus:border-slate-900 focus:outline-none";

export function ChallengeCatalogueClient({
  initialChallenges,
}: {
  initialChallenges: ChallengeManifest[];
}) {
  const queryClient = useQueryClient();
  const [query, setQuery] = useState("");
  const [ecosystem, setEcosystem] = useState("all");
  const [difficulty, setDifficulty] = useState<"all" | DifficultyTier>("all");
  const [category, setCategory] = useState("all");
  const [language, setLanguage] = useState("all");
  const [kind, setKind] = useState<KindFilter>("all");
  const [sort, setSort] = useState<SortKey>("recommended");
  const [hydrated, setHydrated] = useState(false);

  // Read filters from the URL once, so links like /challenges?difficulty=hard work.
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const diff = params.get("difficulty");
    if (params.get("q")) setQuery(params.get("q")!);
    if (params.get("ecosystem")) setEcosystem(params.get("ecosystem")!);
    if (diff && diff !== "all") setDifficulty(normalizeDifficulty(diff));
    if (params.get("category")) setCategory(params.get("category")!);
    if (params.get("language")) setLanguage(params.get("language")!);
    const k = params.get("kind");
    if (k === "engineering" || k === "security") setKind(k);
    const so = params.get("sort");
    if (so === "easiest" || so === "hardest" || so === "points" || so === "title") setSort(so);
    setHydrated(true);
  }, []);

  // Keep the URL in step with the filters so a filtered view can be shared or bookmarked.
  useEffect(() => {
    if (!hydrated) return;
    const params = new URLSearchParams();
    if (query.trim()) params.set("q", query.trim());
    if (ecosystem !== "all") params.set("ecosystem", ecosystem);
    if (difficulty !== "all") params.set("difficulty", difficulty);
    if (category !== "all") params.set("category", category);
    if (language !== "all") params.set("language", language);
    if (kind !== "all") params.set("kind", kind);
    if (sort !== "recommended") params.set("sort", sort);
    const qs = params.toString();
    window.history.replaceState(null, "", qs ? `?${qs}` : window.location.pathname);
  }, [hydrated, query, ecosystem, difficulty, category, language, kind, sort]);

  const languages = useMemo(
    () => [...new Set(initialChallenges.map((c) => c.language))].sort(),
    [initialChallenges]
  );
  const usedEcosystems = useMemo(
    () => new Set(initialChallenges.map((c) => c.ecosystem)),
    [initialChallenges]
  );
  const usedCategories = useMemo(
    () => new Set(initialChallenges.map((c) => c.category)),
    [initialChallenges]
  );

  const { data: meData } = useQuery<{
    bookmarks?: string[];
    unlocks?: Array<{ challengeSlug: string; passed: boolean }>;
  }>({
    queryKey: ["auth-me"],
    queryFn: async () => (await fetch("/api/v1/auth/me")).json(),
  });

  const bookmarked = useMemo(() => new Set(meData?.bookmarks ?? []), [meData?.bookmarks]);
  const passedSlugs = useMemo(
    () => new Set((meData?.unlocks ?? []).filter((u) => u.passed).map((u) => u.challengeSlug)),
    [meData?.unlocks]
  );

  // Everything except the tier filter, so each tier chip can show how many it would match.
  const matchesOtherFilters = useMemo(() => {
    const q = query.trim().toLowerCase();
    return initialChallenges.filter((c) => {
      if (ecosystem !== "all" && c.ecosystem !== ecosystem) return false;
      if (category !== "all" && c.category !== category) return false;
      if (language !== "all" && c.language !== language) return false;
      if (kind === "security" && !c.is_security_mission) return false;
      if (kind === "engineering" && c.is_security_mission) return false;
      if (
        q &&
        !c.slug.toLowerCase().includes(q) &&
        !c.title.toLowerCase().includes(q) &&
        !c.description.toLowerCase().includes(q) &&
        !c.tags.some((t) => t.toLowerCase().includes(q))
      ) {
        return false;
      }
      return true;
    });
  }, [initialChallenges, query, ecosystem, category, language, kind]);

  const tierCounts = useMemo(() => {
    const counts = Object.fromEntries(DIFFICULTY_TIERS.map((t) => [t, 0])) as Record<
      DifficultyTier,
      number
    >;
    for (const c of matchesOtherFilters) counts[normalizeDifficulty(c.difficulty)] += 1;
    return counts;
  }, [matchesOtherFilters]);

  const filtered = useMemo(() => {
    const rank = (c: ChallengeManifest) => DIFFICULTY_META[normalizeDifficulty(c.difficulty)].rank;
    const list = matchesOtherFilters.filter(
      (c) => difficulty === "all" || normalizeDifficulty(c.difficulty) === difficulty
    );
    const sorted = [...list];
    if (sort === "easiest" || sort === "recommended") {
      sorted.sort((a, b) => rank(a) - rank(b) || a.title.localeCompare(b.title));
    } else if (sort === "hardest") {
      sorted.sort((a, b) => rank(b) - rank(a) || a.title.localeCompare(b.title));
    } else if (sort === "points") {
      sorted.sort((a, b) => b.scoring.max_points - a.scoring.max_points || rank(b) - rank(a));
    } else {
      sorted.sort((a, b) => a.title.localeCompare(b.title));
    }
    return sorted;
  }, [matchesOtherFilters, difficulty, sort]);

  const activeFilterCount =
    Number(Boolean(query.trim())) +
    Number(ecosystem !== "all") +
    Number(difficulty !== "all") +
    Number(category !== "all") +
    Number(language !== "all") +
    Number(kind !== "all");

  function clearFilters() {
    setQuery("");
    setEcosystem("all");
    setDifficulty("all");
    setCategory("all");
    setLanguage("all");
    setKind("all");
  }

  async function toggleBookmark(slug: string) {
    const res = await fetch("/api/v1/bookmarks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ challengeSlug: slug }),
    });
    if (res.ok) {
      await queryClient.invalidateQueries({ queryKey: ["auth-me"] });
    }
  }

  return (
    <div className="space-y-6">
      <div className="space-y-4 rounded-lg border border-zinc-200 bg-white p-4">
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-3 h-4 w-4 text-zinc-400" />
          <Input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search title, tag, standard…"
            aria-label="Search challenges"
            className="h-10 pl-9"
          />
        </div>

        <div role="group" aria-label="Difficulty" className="-mx-1 flex gap-2 overflow-x-auto px-1 pb-1">
          <button
            type="button"
            aria-pressed={difficulty === "all"}
            onClick={() => setDifficulty("all")}
            className={`shrink-0 cursor-pointer rounded-full border px-3.5 py-1.5 text-xs font-medium transition-colors ${
              difficulty === "all"
                ? "border-slate-900 bg-slate-900 text-white"
                : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
            }`}
          >
            All levels
            <span className="ml-1.5 font-mono opacity-70">{matchesOtherFilters.length}</span>
          </button>
          {DIFFICULTY_TIERS.map((tier) => {
            const meta = DIFFICULTY_META[tier];
            const active = difficulty === tier;
            return (
              <button
                key={tier}
                type="button"
                aria-pressed={active}
                title={meta.blurb}
                onClick={() => setDifficulty(active ? "all" : tier)}
                className={`inline-flex shrink-0 cursor-pointer items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-xs font-medium transition-colors ${
                  active
                    ? `${meta.light} ring-2 ring-slate-900/80`
                    : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
                }`}
              >
                <span className={`h-2 w-2 rounded-full ${meta.dot}`} aria-hidden />
                {meta.label}
                <span className="font-mono opacity-60">{tierCounts[tier]}</span>
              </button>
            );
          })}
        </div>

        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <select
            value={ecosystem}
            onChange={(e) => setEcosystem(e.target.value)}
            aria-label="Ecosystem"
            className={SELECT}
          >
            <option value="all">All ecosystems</option>
            {ECOSYSTEM_REGISTRY.filter((eco) => usedEcosystems.has(eco.id)).map((eco) => (
              <option key={eco.id} value={eco.id}>
                {eco.name}
              </option>
            ))}
          </select>

          <select
            value={language}
            onChange={(e) => setLanguage(e.target.value)}
            aria-label="Language"
            className={SELECT}
          >
            <option value="all">All languages</option>
            {languages.map((l) => (
              <option key={l} value={l}>
                {l}
              </option>
            ))}
          </select>

          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            aria-label="Category"
            className={SELECT}
          >
            <option value="all">All categories</option>
            {CHALLENGE_CATEGORIES.filter((cat) => usedCategories.has(cat.id)).map((cat) => (
              <option key={cat.id} value={cat.id}>
                {cat.label}
              </option>
            ))}
          </select>

          <select
            value={kind}
            onChange={(e) => setKind(e.target.value as KindFilter)}
            aria-label="Type"
            className={SELECT}
          >
            <option value="all">All types</option>
            <option value="engineering">Engineering challenges</option>
            <option value="security">Security missions</option>
          </select>

          <select
            value={sort}
            onChange={(e) => setSort(e.target.value as SortKey)}
            aria-label="Sort"
            className={SELECT}
          >
            <option value="recommended">Sort: easiest first</option>
            <option value="hardest">Sort: hardest first</option>
            <option value="points">Sort: most points</option>
            <option value="title">Sort: A to Z</option>
          </select>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-zinc-500">
          <p aria-live="polite">
            Showing <span className="font-semibold text-zinc-900">{filtered.length}</span> of{" "}
            {initialChallenges.length} challenges
          </p>
          {activeFilterCount > 0 && (
            <button
              type="button"
              onClick={clearFilters}
              className="cursor-pointer rounded font-medium text-blue-700 hover:underline"
            >
              Clear {activeFilterCount} filter{activeFilterCount === 1 ? "" : "s"}
            </button>
          )}
        </div>
      </div>

      {filtered.length === 0 ? (
        <Card className="p-10 text-center">
          <p className="text-sm font-medium text-zinc-900">No matching challenges</p>
          <p className="mt-1 text-xs text-zinc-500">
            No published challenge fits this combination yet. Try another level or clear the
            filters.
          </p>
          <button
            type="button"
            onClick={clearFilters}
            className="mt-4 cursor-pointer rounded-md bg-slate-900 px-3 py-1.5 text-xs font-medium text-white hover:bg-slate-800"
          >
            Clear filters
          </button>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {filtered.map((c) => (
            <Card key={c.slug} className="flex flex-col justify-between p-5">
              <div>
                <div className="flex items-center justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-1.5">
                    <Badge tone="blue">{c.ecosystem}</Badge>
                    {c.is_security_mission && (
                      <Badge tone="red">
                        <Shield className="mr-1 h-3 w-3" />
                        Security
                      </Badge>
                    )}
                    {passedSlugs.has(c.slug) && (
                      <Badge tone="green">
                        <CheckCircle2 className="mr-1 h-3 w-3" />
                        Passed
                      </Badge>
                    )}
                  </div>
                  <button
                    type="button"
                    onClick={() => toggleBookmark(c.slug)}
                    title="Bookmark (needs an account)"
                    aria-label={`Bookmark ${c.title}`}
                    aria-pressed={bookmarked.has(c.slug)}
                    className="shrink-0 text-zinc-400 hover:text-zinc-900 cursor-pointer"
                  >
                    <Bookmark
                      className={`h-4 w-4 ${bookmarked.has(c.slug) ? "fill-zinc-900 text-zinc-900" : ""}`}
                    />
                  </button>
                </div>

                <Link href={`/challenges/${c.slug}`} className="mt-3 block group">
                  <h2 className="text-base font-semibold text-zinc-950 group-hover:text-blue-700">
                    {c.title}
                  </h2>
                </Link>
                <p className="mt-1.5 line-clamp-4 text-xs leading-relaxed text-zinc-600">{c.description}</p>

                <div className="mt-3 flex flex-wrap gap-1.5">
                  {c.tags.slice(0, 4).map((t) => (
                    <span
                      key={t}
                      className="rounded bg-zinc-100 px-2 py-0.5 font-mono text-[11px] text-zinc-600"
                    >
                      {t}
                    </span>
                  ))}
                </div>
              </div>

              <div className="mt-5 flex flex-wrap items-center justify-between gap-2 border-t border-zinc-100 pt-3">
                <div className="flex items-center gap-2 text-xs text-zinc-500">
                  <DifficultyBadge difficulty={c.difficulty} />
                  <span className="font-mono">{c.scoring.max_points} pts</span>
                </div>
                <div className="flex items-center gap-2">
                  <Link
                    href={`/challenges/${c.slug}`}
                    className="rounded border border-zinc-200 px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50"
                  >
                    Specs
                  </Link>
                  <Link
                    href={`/workspace/${c.slug}`}
                    className="inline-flex items-center gap-1 rounded bg-slate-900 px-2.5 py-1 text-xs font-medium text-white hover:bg-slate-800"
                  >
                    <Code2 className="h-3 w-3" />
                    Solve
                  </Link>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
