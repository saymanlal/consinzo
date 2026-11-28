import type { Metadata } from "next";
import { pageMetadata } from "@/lib/site";
import Link from "next/link";
import { ArrowRight, BookOpen, CheckCircle2, Cpu, ExternalLink, XCircle } from "lucide-react";
import { ECOSYSTEM_REGISTRY, SUPPORT_LEVEL_LABELS } from "@consinzo/ecosystem-registry";
import { Badge, Card } from "@consinzo/ui";
import { listPublishedChallenges } from "@/lib/challenges";
import { KNOWLEDGE_ENTRIES } from "@/lib/knowledge";

export const metadata: Metadata = pageMetadata({
  title: "Blockchain Ecosystems and Toolchains",
  description:
    "Ten blockchain ecosystems with pinned toolchain versions and an honest support level for each, from reference-only to automated evaluation.",
  path: "/ecosystems",
});

export default function EcosystemsPage() {
  const allChallenges = listPublishedChallenges();

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6">
      <div className="border-b border-zinc-200 pb-6">
        <div className="inline-flex items-center gap-1.5 text-xs font-mono uppercase tracking-wider text-zinc-500">
          <Cpu className="h-4 w-4 text-blue-700" />
          Ecosystem Registry
        </div>
        <h1 className="mt-2 text-2xl font-semibold text-zinc-950">
          Supported Blockchain Ecosystems & Toolchains
        </h1>
        <p className="mt-1 text-sm text-zinc-600 max-w-3xl">
          Each ecosystem has an explicit adapter and verified capability flags. Support levels are
          strictly gated by tested compiler and runtime integrations.
        </p>
      </div>

      <div className="mt-8 grid gap-4 md:grid-cols-2">
        {ECOSYSTEM_REGISTRY.map((eco) => {
          const level = SUPPORT_LEVEL_LABELS[eco.supportLevel];
          const ecoChallenges = allChallenges.filter((c) => c.ecosystem === eco.id);
          const guide = KNOWLEDGE_ENTRIES.find((k) => k.ecosystemId === eco.id);
          return (
            <Card key={eco.id} className="p-5 space-y-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-base font-semibold text-zinc-950">{eco.name}</h2>
                    <span className="font-mono text-xs text-zinc-400">({eco.shortName})</span>
                  </div>
                  <div className="mt-1 font-mono text-xs text-zinc-500">
                    Adapter: {eco.adapterId}
                  </div>
                </div>
                <Badge tone={eco.supportLevel >= 3 ? "green" : eco.supportLevel === 1 ? "blue" : "neutral"}>
                  Level {eco.supportLevel}: {level.name}
                </Badge>
              </div>

              <p className="text-xs leading-relaxed text-zinc-600">{eco.architectureNotes}</p>

              <div className="grid grid-cols-2 gap-2 text-xs">
                {(
                  [
                    ["Editor Syntax", eco.capabilities.editorSyntax],
                    ["Local Compile", eco.capabilities.localCliCompile],
                    ["Test Execution", eco.capabilities.localCliTest],
                    ["Hidden Eval", eco.capabilities.remoteHiddenEval],
                  ] as const
                ).map(([label, enabled]) => (
                  <div
                    key={label}
                    className="flex items-center gap-1.5 rounded border border-zinc-200 bg-zinc-50 px-2.5 py-1.5"
                  >
                    {enabled ? (
                      <CheckCircle2 className="h-3.5 w-3.5 text-emerald-700" />
                    ) : (
                      <XCircle className="h-3.5 w-3.5 text-zinc-400" />
                    )}
                    <span className={enabled ? "text-zinc-900 font-medium" : "text-zinc-500"}>
                      {label}
                    </span>
                  </div>
                ))}
              </div>

              <div className="border-t border-zinc-100 pt-3 flex flex-wrap items-center justify-between gap-2 text-xs">
                <div className="font-mono text-zinc-600">
                  Toolchains: {eco.toolchains.map((t) => `${t.name} (${t.pinnedVersion})`).join(" · ")}
                </div>
                <div className="flex flex-wrap items-center gap-3 shrink-0">
                  {guide && (
                    <Link
                      href={`/knowledge/${guide.slug}`}
                      className="inline-flex items-center gap-1 font-medium text-zinc-700 hover:text-zinc-950"
                    >
                      <BookOpen className="h-3 w-3" />
                      Guide
                    </Link>
                  )}
                  {ecoChallenges.length > 0 && (
                    <Link
                      href={`/challenges?ecosystem=${eco.id}`}
                      className="inline-flex items-center gap-1 font-semibold text-blue-700 hover:underline"
                    >
                      {ecoChallenges.length} Challenges
                      <ArrowRight className="h-3 w-3" />
                    </Link>
                  )}
                  <a
                    href={eco.officialDocsUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1 text-zinc-500 hover:text-zinc-900"
                  >
                    Docs
                    <ExternalLink className="h-3 w-3" />
                  </a>
                </div>
              </div>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
