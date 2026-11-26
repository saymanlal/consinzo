import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, ArrowRight, BookOpen, ExternalLink, Terminal } from "lucide-react";
import { Badge, Card } from "@consinzo/ui";
import { KNOWLEDGE_ENTRIES, getKnowledgeEntryBySlug } from "@/lib/knowledge";

export function generateStaticParams() {
  return KNOWLEDGE_ENTRIES.map((entry) => ({ slug: entry.slug }));
}

export default async function KnowledgeDetailPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const entry = getKnowledgeEntryBySlug(slug);
  if (!entry) {
    notFound();
  }

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 lg:px-6">
      <Link
        href="/knowledge"
        className="inline-flex items-center gap-1.5 text-xs font-medium text-zinc-600 hover:text-zinc-950"
      >
        <ArrowLeft className="h-3.5 w-3.5" />
        Back to Knowledge Hub
      </Link>

      <div className="mt-5 border-b border-zinc-200 pb-6">
        <div className="flex flex-wrap items-center gap-2">
          <Badge tone="blue">{entry.ecosystemId}</Badge>
          <Badge tone="neutral">{entry.entryType}</Badge>
          <Badge tone="green">{entry.reviewStatus}</Badge>
          <span className="font-mono text-xs text-zinc-500">
            Version: {entry.applicableVersion} · Verified {entry.lastVerifiedAt}
          </span>
        </div>

        <h1 className="mt-3 text-2xl font-semibold text-zinc-950">{entry.title}</h1>
        <p className="mt-2 text-sm leading-relaxed text-zinc-600">{entry.summary}</p>

        <div className="mt-4 flex flex-wrap items-center gap-4 text-xs">
          <a
            href={entry.sourceUrl}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1.5 font-medium text-blue-700 hover:underline"
          >
            <BookOpen className="h-3.5 w-3.5" />
            Official Reference: {entry.source}
            <ExternalLink className="h-3 w-3" />
          </a>
        </div>
      </div>

      <div className="mt-8 space-y-6">
        {entry.bodySections.map((section) => (
          <Card key={section.heading} className="p-6">
            <h2 className="text-base font-semibold text-zinc-950">{section.heading}</h2>
            <p className="mt-2 text-sm leading-relaxed text-zinc-700">{section.content}</p>
            {section.codeExample && (
              <pre className="mt-4 overflow-x-auto rounded-lg border border-zinc-800 bg-[#0D1117] p-4 font-mono text-xs leading-relaxed text-zinc-100">
                <code>{section.codeExample}</code>
              </pre>
            )}
          </Card>
        ))}
      </div>

      {entry.relatedChallengeSlugs.length > 0 && (
        <div className="mt-8">
          <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-zinc-500">
            <Terminal className="h-3.5 w-3.5 text-blue-700" />
            Practice In Live Consinzo Challenges
          </div>
          <div className="mt-3 grid gap-3 sm:grid-cols-2">
            {entry.relatedChallengeSlugs.map((cSlug) => (
              <Link
                key={cSlug}
                href={`/workspace/${cSlug}`}
                className="flex items-center justify-between rounded-lg border border-zinc-200 bg-white px-4 py-3 text-xs font-medium text-zinc-900 hover:border-blue-600 hover:text-blue-700 transition"
              >
                <span className="font-mono">{cSlug}</span>
                <ArrowRight className="h-3.5 w-3.5" />
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
