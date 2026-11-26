"use client";

import React, { useMemo, useState } from "react";
import Link from "next/link";
import { ArrowRight, ExternalLink, Search } from "lucide-react";
import { Badge, Card, Input } from "@consinzo/ui";
import type { KnowledgeEntry } from "@/lib/knowledge";

export function KnowledgeExplorer({ entries }: { entries: readonly KnowledgeEntry[] }) {
  const [query, setQuery] = useState("");
  const [ecosystem, setEcosystem] = useState("all");
  const [entryType, setEntryType] = useState("all");

  const ecosystems = useMemo(
    () => Array.from(new Set(entries.map((e) => e.ecosystemId))),
    [entries]
  );
  const entryTypes = useMemo(
    () => Array.from(new Set(entries.map((e) => e.entryType))),
    [entries]
  );

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return entries.filter((e) => {
      if (ecosystem !== "all" && e.ecosystemId !== ecosystem) return false;
      if (entryType !== "all" && e.entryType !== entryType) return false;
      if (
        q &&
        !e.title.toLowerCase().includes(q) &&
        !e.summary.toLowerCase().includes(q) &&
        !e.ecosystemId.toLowerCase().includes(q) &&
        !e.applicableVersion.toLowerCase().includes(q)
      ) {
        return false;
      }
      return true;
    });
  }, [entries, query, ecosystem, entryType]);

  return (
    <div className="mt-6 space-y-6">
      <div className="grid gap-3 rounded-lg border border-zinc-200 bg-white p-4 md:grid-cols-3">
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-zinc-400" />
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search standard, SDK, ecosystem, version..."
            className="pl-9"
          />
        </div>

        <select
          value={ecosystem}
          onChange={(e) => setEcosystem(e.target.value)}
          className="h-9 rounded-md border border-zinc-300 bg-white px-3 text-sm text-zinc-800"
        >
          <option value="all">All Ecosystems ({ecosystems.length})</option>
          {ecosystems.map((eco) => (
            <option key={eco} value={eco}>
              {eco}
            </option>
          ))}
        </select>

        <select
          value={entryType}
          onChange={(e) => setEntryType(e.target.value)}
          className="h-9 rounded-md border border-zinc-300 bg-white px-3 text-sm text-zinc-800"
        >
          <option value="all">All Reference Types</option>
          {entryTypes.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </select>
      </div>

      {filtered.length === 0 ? (
        <Card className="p-8 text-center text-xs text-zinc-500">
          No knowledge entries match your current filter.
        </Card>
      ) : (
        <div className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
          {filtered.map((entry) => (
            <Card key={entry.slug} className="p-5 flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-1.5">
                    <Badge tone="blue">{entry.ecosystemId}</Badge>
                    <Badge tone="neutral">{entry.entryType}</Badge>
                  </div>
                  <Badge tone="green">{entry.reviewStatus}</Badge>
                </div>
                <h2 className="mt-3 text-base font-semibold text-zinc-950">
                  <Link href={`/knowledge/${entry.slug}`} className="hover:text-blue-700 transition">
                    {entry.title}
                  </Link>
                </h2>
                <p className="mt-1.5 text-xs leading-relaxed text-zinc-600">{entry.summary}</p>
              </div>

              <div className="mt-5 border-t border-zinc-100 pt-3 space-y-2 text-xs text-zinc-500">
                <div className="flex items-center justify-between">
                  <span>Applicable Version</span>
                  <span className="font-mono text-zinc-800">{entry.applicableVersion}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span>Last Verified</span>
                  <span className="font-mono text-zinc-800">{entry.lastVerifiedAt}</span>
                </div>
                <div className="flex items-center justify-between pt-2">
                  <Link
                    href={`/knowledge/${entry.slug}`}
                    className="inline-flex items-center gap-1 font-semibold text-zinc-950 hover:text-blue-700"
                  >
                    Read Deep Dive
                    <ArrowRight className="h-3 w-3" />
                  </Link>
                  <a
                    href={entry.sourceUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1 text-blue-700 hover:underline font-medium"
                  >
                    Docs
                    <ExternalLink className="h-3 w-3" />
                  </a>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
