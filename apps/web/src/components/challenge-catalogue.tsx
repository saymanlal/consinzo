"use client";

import React, { useMemo, useState } from "react";
import Link from "next/link";
import { Bookmark, Code2, Search, Shield } from "lucide-react";
import type { ChallengeManifest } from "@consinzo/challenge-spec";
import { CHALLENGE_CATEGORIES } from "@consinzo/shared";
import { ECOSYSTEM_REGISTRY } from "@consinzo/ecosystem-registry";
import { Badge, Card, Input } from "@consinzo/ui";

export function ChallengeCatalogueClient({
  initialChallenges,
}: {
  initialChallenges: ChallengeManifest[];
}) {
  const [query, setQuery] = useState("");
  const [ecosystem, setEcosystem] = useState("all");
  const [difficulty, setDifficulty] = useState("all");
  const [category, setCategory] = useState("all");
  const [bookmarked, setBookmarked] = useState<Set<string>>(new Set());

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return initialChallenges.filter((c) => {
      if (ecosystem !== "all" && c.ecosystem !== ecosystem) return false;
      if (difficulty !== "all" && c.difficulty !== difficulty) return false;
      if (category !== "all" && c.category !== category) return false;
      if (
        q &&
        !c.title.toLowerCase().includes(q) &&
        !c.description.toLowerCase().includes(q) &&
        !c.tags.some((t) => t.toLowerCase().includes(q))
      ) {
        return false;
      }
      return true;
    });
  }, [initialChallenges, query, ecosystem, difficulty, category]);

  async function toggleBookmark(slug: string) {
    const res = await fetch("/api/v1/bookmarks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ challengeSlug: slug }),
    });
    if (res.ok) {
      const json = (await res.json()) as { bookmarked: boolean };
      setBookmarked((prev) => {
        const next = new Set(prev);
        if (json.bookmarked) next.add(slug);
        else next.delete(slug);
        return next;
      });
    }
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-3 rounded-lg border border-zinc-200 bg-white p-4 md:grid-cols-4">
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-zinc-400" />
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search title, tag, standard..."
            className="pl-9"
          />
        </div>

        <select
          value={ecosystem}
          onChange={(e) => setEcosystem(e.target.value)}
          className="h-9 rounded-md border border-zinc-300 bg-white px-3 text-sm text-zinc-800"
        >
          <option value="all">All Ecosystems</option>
          {ECOSYSTEM_REGISTRY.map((eco) => (
            <option key={eco.id} value={eco.id}>
              {eco.name} (L{eco.supportLevel})
            </option>
          ))}
        </select>

        <select
          value={difficulty}
          onChange={(e) => setDifficulty(e.target.value)}
          className="h-9 rounded-md border border-zinc-300 bg-white px-3 text-sm text-zinc-800"
        >
          <option value="all">All Difficulties</option>
          <option value="beginner">Beginner</option>
          <option value="intermediate">Intermediate</option>
          <option value="advanced">Advanced</option>
          <option value="expert">Expert</option>
        </select>

        <select
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          className="h-9 rounded-md border border-zinc-300 bg-white px-3 text-sm text-zinc-800"
        >
          <option value="all">All Categories</option>
          {CHALLENGE_CATEGORIES.map((cat) => (
            <option key={cat.id} value={cat.id}>
              {cat.label}
            </option>
          ))}
        </select>
      </div>

      {filtered.length === 0 ? (
        <Card className="p-10 text-center">
          <p className="text-sm font-medium text-zinc-900">No matching challenges</p>
          <p className="mt-1 text-xs text-zinc-500">
            Adjust filters or clear your search query. Currently only Ethereum/EVM challenges are
            published in Phase 1.
          </p>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {filtered.map((c) => (
            <Card key={c.slug} className="flex flex-col justify-between p-5">
              <div>
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-1.5">
                    <Badge tone="blue">{c.ecosystem}</Badge>
                    {c.is_security_mission && (
                      <Badge tone="red">
                        <Shield className="mr-1 h-3 w-3" />
                        Security
                      </Badge>
                    )}
                  </div>
                  <button
                    type="button"
                    onClick={() => toggleBookmark(c.slug)}
                    title="Toggle bookmark (requires login)"
                    className="text-zinc-400 hover:text-zinc-900 cursor-pointer"
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
                <p className="mt-1.5 text-xs leading-relaxed text-zinc-600">{c.description}</p>

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

              <div className="mt-5 flex items-center justify-between border-t border-zinc-100 pt-3">
                <div className="flex items-center gap-2 text-xs text-zinc-500">
                  <span className="capitalize">{c.difficulty}</span>
                  <span>·</span>
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
