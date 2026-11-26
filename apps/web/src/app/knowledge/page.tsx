import Link from "next/link";
import { ArrowRight, BookOpen, ExternalLink } from "lucide-react";
import { Badge, Card } from "@consinzo/ui";
import { KNOWLEDGE_ENTRIES } from "@/lib/knowledge";

export default function KnowledgePage() {
  const ecosystemsCovered = new Set(KNOWLEDGE_ENTRIES.map((e) => e.ecosystemId)).size;

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6">
      <div className="border-b border-zinc-200 pb-6">
        <div className="inline-flex items-center gap-1.5 text-xs font-mono uppercase tracking-wider text-zinc-500">
          <BookOpen className="h-4 w-4 text-blue-700" />
          Curated Multi-Chain Knowledge Hub
        </div>
        <h1 className="mt-2 text-2xl font-semibold text-zinc-950">
          Versioned Standards, Languages &amp; Security References
        </h1>
        <p className="mt-1 text-sm text-zinc-600 max-w-3xl">
          Every article tracks explicit toolchain versions, official canonical sources, and verification
          dates across all {ecosystemsCovered} supported blockchain ecosystems.
        </p>
      </div>

      <div className="mt-8 grid gap-5 md:grid-cols-2 lg:grid-cols-3">
        {KNOWLEDGE_ENTRIES.map((entry) => (
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
    </div>
  );
}
