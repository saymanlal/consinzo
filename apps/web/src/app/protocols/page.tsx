import Link from "next/link";
import { ArrowRight, CheckSquare, Layers } from "lucide-react";
import { Badge, Card } from "@consinzo/ui";
import { PROTOCOL_LABS } from "@/lib/knowledge";

export default function ProtocolsPage() {
  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6">
      <div className="border-b border-zinc-200 pb-6">
        <div className="inline-flex items-center gap-1.5 text-xs font-mono uppercase tracking-wider text-zinc-500">
          <Layers className="h-4 w-4 text-blue-700" />
          Protocol Lab
        </div>
        <h1 className="mt-2 text-2xl font-semibold text-zinc-950">
          DeFi & Protocol Engineering Laboratories
        </h1>
        <p className="mt-1 text-sm text-zinc-600 max-w-3xl">
          Architecture walkthroughs, invariant specifications, and direct hands-on implementation
          workspaces for core decentralized protocols.
        </p>
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-3">
        {PROTOCOL_LABS.map((lab) => (
          <Card key={lab.slug} className="p-6 flex flex-col justify-between">
            <div>
              <Badge tone="blue">{lab.category}</Badge>
              <h2 className="mt-3 text-lg font-semibold text-zinc-950">{lab.title}</h2>
              <p className="mt-2 text-xs leading-relaxed text-zinc-600">{lab.summary}</p>

              <div className="mt-5">
                <h3 className="text-xs font-semibold uppercase tracking-wider text-zinc-500">
                  Execution Flow
                </h3>
                <ol className="mt-2 space-y-1.5 text-xs text-zinc-700 list-decimal list-inside">
                  {lab.architectureSteps.map((step, i) => (
                    <li key={i}>{step}</li>
                  ))}
                </ol>
              </div>

              <div className="mt-5">
                <h3 className="text-xs font-semibold uppercase tracking-wider text-zinc-500">
                  Verified Invariants
                </h3>
                <ul className="mt-2 space-y-1.5 text-xs text-zinc-700">
                  {lab.invariants.map((inv, i) => (
                    <li key={i} className="flex items-start gap-1.5 font-mono text-[11px]">
                      <CheckSquare className="h-3.5 w-3.5 shrink-0 text-emerald-700 mt-0.5" />
                      <span>{inv}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>

            {lab.linkedChallengeSlug && (
              <div className="mt-6 border-t border-zinc-100 pt-4">
                <Link
                  href={`/workspace/${lab.linkedChallengeSlug}`}
                  className="inline-flex items-center gap-1.5 text-xs font-medium text-blue-700 hover:underline"
                >
                  Open Lab Implementation Workspace
                  <ArrowRight className="h-3.5 w-3.5" />
                </Link>
              </div>
            )}
          </Card>
        ))}
      </div>
    </div>
  );
}
