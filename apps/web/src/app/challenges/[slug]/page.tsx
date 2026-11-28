import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import {
  ArrowLeft,
  ArrowRight,
  CheckCircle2,
  Code2,
  ExternalLink,
  FileCode2,
  Lock,
  Shield,
} from "lucide-react";
import { getEcosystemById } from "@consinzo/ecosystem-registry";
import { getDifficultyMeta } from "@/lib/difficulty";
import { absoluteUrl, pageMetadata, SITE } from "@/lib/site";
import { JsonLd } from "@/components/json-ld";
import { DifficultyBadge } from "@/components/difficulty-badge";
import { Badge, Card } from "@consinzo/ui";
import { ChallengeDetailActions } from "@/components/challenge-detail-actions";
import { ChallengeErrorState } from "@/components/challenge-error-state";
import {
  getAdjacentChallenges,
  getChallengeBySlug,
  getPublishedChallenges,
  getRelatedChallenges,
} from "@/lib/challenges";

export const dynamicParams = true;

export function generateStaticParams() {
  return getPublishedChallenges().map((c) => ({ slug: c.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const outcome = getChallengeBySlug(slug);
  if (outcome.status === "error") return { title: "Challenge not found", robots: { index: false } };
  const m = outcome.data.manifest;
  const tier = getDifficultyMeta(m.difficulty).label;
  const kind = m.is_security_mission ? "security mission" : "challenge";
  return {
    ...pageMetadata({
      title: `${m.title} (${m.language}, ${tier})`,
      description: `${tier} ${m.language} ${kind}: ${m.description}`.slice(0, 300),
      path: `/challenges/${m.slug}`,
    }),
    keywords: [...m.tags, m.language, getEcosystemById(m.ecosystem)?.name ?? m.ecosystem, tier],
  };
}

export default async function ChallengeDetailPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const outcome = getChallengeBySlug(slug);

  if (outcome.status === "error") {
    if (
      outcome.kind === "not_found" ||
      outcome.kind === "invalid_slug" ||
      outcome.kind === "unpublished"
    ) {
      notFound();
    }
    if (outcome.kind === "storage_error") {
      return (
        <ChallengeErrorState
          code="STORAGE_UNAVAILABLE"
          title="Unable to load challenge data right now"
          message={outcome.message}
          recoverable={true}
        />
      );
    }
    return (
      <ChallengeErrorState
        code="CHALLENGE_INCOMPLETE"
        title="Challenge package is incomplete"
        message={outcome.message}
        recoverable={false}
      />
    );
  }

  const { manifest, readmeMarkdown, starterFiles, publicTests, hasHiddenTests } = outcome.data;
  const ecosystem = getEcosystemById(manifest.ecosystem);
  const related = getRelatedChallenges(manifest.id, 3);
  const { previous, next } = getAdjacentChallenges(manifest.slug);
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "LearningResource",
        "@id": absoluteUrl(`/challenges/${manifest.slug}#resource`),
        name: manifest.title,
        description: manifest.description,
        url: absoluteUrl(`/challenges/${manifest.slug}`),
        learningResourceType: manifest.is_security_mission
          ? "Security exercise"
          : "Programming exercise",
        educationalLevel: getDifficultyMeta(manifest.difficulty).label,
        programmingLanguage: manifest.language,
        teaches: manifest.tags,
        keywords: manifest.tags.join(", "),
        inLanguage: "en",
        isAccessibleForFree: true,
        version: manifest.version,
        provider: { "@type": "Organization", name: SITE.name, url: absoluteUrl("/") },
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "Home", item: absoluteUrl("/") },
          { "@type": "ListItem", position: 2, name: "Challenges", item: absoluteUrl("/challenges") },
          {
            "@type": "ListItem",
            position: 3,
            name: manifest.title,
            item: absoluteUrl(`/challenges/${manifest.slug}`),
          },
        ],
      },
    ],
  };

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 lg:px-6 space-y-8">
      <JsonLd data={jsonLd} />
      <div className="flex flex-wrap items-start justify-between gap-4 border-b border-zinc-200 pb-6">
        <div className="max-w-3xl">
          <div className="flex flex-wrap items-center gap-2">
            <Badge tone="blue">{ecosystem?.name ?? manifest.ecosystem}</Badge>
            <Badge tone="neutral">{manifest.language}</Badge>
<DifficultyBadge difficulty={manifest.difficulty} />
            <Badge tone="neutral">{manifest.category}</Badge>
            <Badge tone="green">
              <CheckCircle2 className="mr-1 h-3 w-3" />
              {manifest.publication_status}
            </Badge>
            {manifest.is_security_mission && <Badge tone="red">Security Mission</Badge>}
          </div>
          <h1 className="mt-3 text-2xl font-semibold text-zinc-950">{manifest.title}</h1>
          <p className="mt-1.5 text-sm text-zinc-600">{manifest.description}</p>
        </div>

        <Link
          href={`/workspace/${manifest.slug}`}
          className="inline-flex items-center gap-2 rounded-md bg-slate-900 px-4 py-2.5 text-sm font-medium text-white hover:bg-slate-800"
        >
          <Code2 className="h-4 w-4" />
          Start Coding
          <ArrowRight className="h-4 w-4" />
        </Link>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2 space-y-6">
          <Card className="p-6">
            <h2 className="text-xs font-semibold uppercase tracking-wider text-zinc-500">
              Problem Statement &amp; Requirements
            </h2>
            <pre className="mt-3 whitespace-pre-wrap font-sans text-sm leading-relaxed text-zinc-800">
              {readmeMarkdown}
            </pre>
          </Card>

          <Card className="p-6 space-y-3">
            <h2 className="text-xs font-semibold uppercase tracking-wider text-zinc-500">
              Starter Project Files ({starterFiles.length})
            </h2>
            <div className="grid gap-2 sm:grid-cols-2">
              {starterFiles.map((sf) => (
                <div
                  key={sf.path}
                  className="flex items-center justify-between rounded border border-zinc-200 bg-zinc-50 px-3 py-2 font-mono text-xs"
                >
                  <span className="flex items-center gap-2 text-zinc-800">
                    <FileCode2 className="h-3.5 w-3.5 text-blue-700" />
                    {sf.path}
                  </span>
                  <span className="text-[11px] text-zinc-500">
                    {sf.readOnly ? "read-only" : "editable"}
                  </span>
                </div>
              ))}
            </div>
          </Card>

          <Card className="p-6">
            <h2 className="text-xs font-semibold uppercase tracking-wider text-zinc-500">
              Public Test Suite ({publicTests.length} file)
            </h2>
            {publicTests.map((t) => (
              <div key={t.path} className="mt-3">
                <div className="font-mono text-xs text-zinc-500 mb-2">{t.path}</div>
                <pre className="overflow-x-auto rounded-md border border-zinc-200 bg-zinc-950 p-4 font-mono text-xs text-zinc-200">
                  {t.content}
                </pre>
              </div>
            ))}
          </Card>
        </div>

        <div className="space-y-4">
          <ChallengeDetailActions
            slug={manifest.slug}
            maxPoints={manifest.scoring.max_points}
            unlockPolicy={manifest.solution_unlock_policy}
            hints={manifest.hints}
          />

          <Card className="p-5 space-y-3 text-xs">
            <h3 className="font-semibold text-zinc-950">Toolchain &amp; Evaluation</h3>
            <div className="flex justify-between">
              <span className="text-zinc-500">Compiler</span>
              <span className="font-mono text-zinc-900">
                {manifest.toolchain.compiler} {manifest.toolchain.version}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-zinc-500">Runner</span>
              <span className="font-mono text-zinc-900">{manifest.toolchain.runner}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-zinc-500">Max Score</span>
              <span className="font-mono text-zinc-900">{manifest.scoring.max_points} pts</span>
            </div>
            <div className="flex justify-between">
              <span className="text-zinc-500">Hidden Evaluation</span>
              <span className="inline-flex items-center gap-1 font-medium text-zinc-900">
                <Lock className="h-3 w-3 text-zinc-500" />
                {hasHiddenTests ? "Server-Isolated" : "Public Only"}
              </span>
            </div>
          </Card>

          <Card className="p-5 space-y-2 text-xs">
            <h3 className="font-semibold text-zinc-950">Scoring Weights</h3>
            <div className="flex justify-between">
              <span className="text-zinc-500">Functional Correctness</span>
              <span className="font-mono">{manifest.scoring.weights.functional_correctness}%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-zinc-500">Security &amp; Invariants</span>
              <span className="font-mono">{manifest.scoring.weights.security_invariants}%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-zinc-500">
                {manifest.ecosystem === "near" ? "Execution Efficiency" : "Gas Efficiency"}
              </span>
              <span className="font-mono">{manifest.scoring.weights.efficiency}%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-zinc-500">Code Quality</span>
              <span className="font-mono">{manifest.scoring.weights.code_quality}%</span>
            </div>
          </Card>

          <Card className="p-5 space-y-2 text-xs">
            <h3 className="font-semibold text-zinc-950">Verified Documentation</h3>
            {manifest.documentation_references.map((ref) => (
              <a
                key={ref.url}
                href={ref.url}
                target="_blank"
                rel="noreferrer"
                className="flex items-center justify-between rounded border border-zinc-200 p-2 hover:bg-zinc-50"
              >
                <div>
                  <div className="font-medium text-zinc-900">{ref.title}</div>
                  <div className="text-[11px] text-zinc-500">
                    {ref.source} · v{ref.version} · Verified {ref.verified_at}
                  </div>
                </div>
                <ExternalLink className="h-3.5 w-3.5 text-zinc-400" />
              </a>
            ))}
          </Card>

          {manifest.is_security_mission && (
            <Card className="p-5 bg-amber-50/50 border-amber-200 text-xs">
              <div className="flex items-center gap-1.5 font-semibold text-amber-900">
                <Shield className="h-3.5 w-3.5" />
                Security Mission Notice
              </div>
              <p className="mt-1 text-amber-800">
                Automated exploit/invariant tests verify known regression cases only and are not a
                substitute for a full professional security audit.
              </p>
            </Card>
          )}
        </div>
      </div>

      {/* Related Challenges */}
      {related.length > 0 && (
        <section className="border-t border-zinc-200 pt-6">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-zinc-500">
            Related Challenges
          </h2>
          <div className="mt-3 grid gap-4 md:grid-cols-3">
            {related.map((rel) => (
              <Link
                key={rel.slug}
                href={`/challenges/${rel.slug}`}
                className="rounded-lg border border-zinc-200 bg-white p-4 hover:border-zinc-400 transition-colors"
              >
                <div className="flex items-center justify-between text-xs">
                  <Badge tone="blue">{rel.ecosystem}</Badge>
                  <span className="font-mono text-zinc-500">{rel.maxPoints} pts</span>
                </div>
                <div className="mt-2 text-sm font-semibold text-zinc-950">{rel.title}</div>
                <div className="mt-1 font-mono text-[11px] text-zinc-500">
                  {getDifficultyMeta(rel.difficulty).label} · {rel.category}
                </div>
              </Link>
            ))}
          </div>
        </section>
      )}

      {/* Previous / Next Navigation */}
      <nav className="flex flex-wrap items-center justify-between gap-4 border-t border-zinc-200 pt-6 text-xs">
        {previous ? (
          <Link
            href={`/challenges/${previous.slug}`}
            className="inline-flex items-center gap-2 rounded-md border border-zinc-200 bg-white px-3.5 py-2 hover:bg-zinc-50"
          >
            <ArrowLeft className="h-3.5 w-3.5 text-zinc-500" />
            <span>
              <span className="block text-[10px] uppercase text-zinc-400">Previous</span>
              <span className="font-medium text-zinc-900">{previous.title}</span>
            </span>
          </Link>
        ) : (
          <span />
        )}
        {next && (
          <Link
            href={`/challenges/${next.slug}`}
            className="inline-flex items-center gap-2 rounded-md border border-zinc-200 bg-white px-3.5 py-2 text-right hover:bg-zinc-50"
          >
            <span>
              <span className="block text-[10px] uppercase text-zinc-400">Next</span>
              <span className="font-medium text-zinc-900">{next.title}</span>
            </span>
            <ArrowRight className="h-3.5 w-3.5 text-zinc-500" />
          </Link>
        )}
      </nav>
    </div>
  );
}
