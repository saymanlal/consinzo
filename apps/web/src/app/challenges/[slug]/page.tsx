import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowRight, Code2, ExternalLink, Lock, Shield } from "lucide-react";
import { Badge, Card } from "@consinzo/ui";
import { getPublicChallengeBySlug } from "@/lib/challenges";

export default async function ChallengeDetailPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const challenge = getPublicChallengeBySlug(slug);
  if (!challenge) notFound();

  const { manifest, readmeMarkdown, publicTests, hasHiddenTests } = challenge;

  return (
    <div className="mx-auto max-w-5xl px-4 py-8 lg:px-6">
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-zinc-200 pb-6">
        <div>
          <div className="flex items-center gap-2">
            <Badge tone="blue">{manifest.ecosystem}</Badge>
            <Badge tone="neutral">{manifest.language}</Badge>
            <Badge tone="amber">{manifest.difficulty}</Badge>
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
          Open Engineering Workspace
          <ArrowRight className="h-4 w-4" />
        </Link>
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2 space-y-6">
          <Card className="p-6">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-zinc-500">
              Specification
            </h2>
            <pre className="mt-3 whitespace-pre-wrap font-sans text-sm leading-relaxed text-zinc-800">
              {readmeMarkdown}
            </pre>
          </Card>

          <Card className="p-6">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-zinc-500">
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
          <Card className="p-5 space-y-3 text-xs">
            <h3 className="font-semibold text-zinc-950">Toolchain & Evaluation</h3>
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
              <span className="text-zinc-500">Security & Invariants</span>
              <span className="font-mono">{manifest.scoring.weights.security_invariants}%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-zinc-500">Gas Efficiency</span>
              <span className="font-mono">{manifest.scoring.weights.efficiency}%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-zinc-500">Code Quality</span>
              <span className="font-mono">{manifest.scoring.weights.code_quality}%</span>
            </div>
          </Card>

          <Card className="p-5 space-y-2 text-xs">
            <h3 className="font-semibold text-zinc-950">Verified References</h3>
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
    </div>
  );
}
