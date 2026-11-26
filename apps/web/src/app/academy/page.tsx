import Link from "next/link";
import { ArrowRight, GraduationCap } from "lucide-react";
import { Badge, Card } from "@consinzo/ui";
import { LEARNING_PATHS } from "@/lib/knowledge";

export default function AcademyPage() {
  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6">
      <div className="border-b border-zinc-200 pb-6">
        <div className="inline-flex items-center gap-1.5 text-xs font-mono uppercase tracking-wider text-zinc-500">
          <GraduationCap className="h-4 w-4 text-blue-700" />
          Developer Academy
        </div>
        <h1 className="mt-2 text-2xl font-semibold text-zinc-950">
          Structured Engineering Tracks
        </h1>
        <p className="mt-1 text-sm text-zinc-600 max-w-3xl">
          Follow curated challenge tracks from token standards to DeFi protocol invariants and
          exploit defense. Achievements are awarded exclusively from server-verified passes.
        </p>
      </div>

      <div className="mt-8 grid gap-6 md:grid-cols-3">
        {LEARNING_PATHS.map((path) => (
          <Card key={path.slug} className="p-6 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between">
                <Badge tone="blue">{path.ecosystemId}</Badge>
                <Badge tone="neutral">{path.difficulty}</Badge>
              </div>
              <h2 className="mt-3 text-lg font-semibold text-zinc-950">{path.title}</h2>
              <p className="mt-2 text-xs leading-relaxed text-zinc-600">{path.description}</p>

              <div className="mt-5 space-y-2">
                <div className="text-xs font-semibold uppercase tracking-wider text-zinc-500">
                  Track Curriculum ({path.challengeSlugs.length} challenges)
                </div>
                {path.challengeSlugs.map((slug, idx) => (
                  <Link
                    key={slug}
                    href={`/workspace/${slug}`}
                    className="flex items-center justify-between rounded border border-zinc-200 px-3 py-2 text-xs hover:bg-zinc-50"
                  >
                    <span className="font-mono text-zinc-800">
                      0{idx + 1}. {slug}
                    </span>
                    <ArrowRight className="h-3.5 w-3.5 text-zinc-400" />
                  </Link>
                ))}
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
