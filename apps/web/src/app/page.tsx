import Link from "next/link";
import { ArrowRight, CheckCircle2, Code2, Cpu, Layers, Shield, Terminal } from "lucide-react";
import { ECOSYSTEM_REGISTRY, SUPPORT_LEVEL_LABELS } from "@consinzo/ecosystem-registry";
import { Badge, Card } from "@consinzo/ui";
import { listPublishedChallenges } from "@/lib/challenges";
import { PROTOCOL_LABS } from "@/lib/knowledge";

export default function OverviewPage() {
  const challenges = listPublishedChallenges();
  const securityCount = challenges.filter((c) => c.is_security_mission).length;
  const activeExecutionCount = ECOSYSTEM_REGISTRY.filter((e) => e.supportLevel >= 3).length;

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-10 lg:px-6">
      {/* Compact Engineering Header */}
      <section className="border-b border-zinc-200 pb-10">
        <div className="max-w-3xl">
          <div className="inline-flex items-center gap-2 rounded border border-zinc-200 bg-white px-2.5 py-1 text-xs font-mono text-zinc-700">
            <Terminal className="h-3.5 w-3.5 text-blue-700" />
            <span>CONSINZO // THE ENGINEERING PLATFORM</span>
          </div>
          <h1 className="mt-4 text-3xl font-semibold tracking-tight text-zinc-950 sm:text-4xl">
            Build. Test. Break. Master.
          </h1>
          <p className="mt-3 text-base leading-relaxed text-zinc-600">
            Practical smart-contract and protocol engineering environment featuring real{" "}
            <code className="rounded bg-zinc-100 px-1.5 py-0.5 text-xs">solc 0.8.28</code>{" "}
            compilation, EthereumJS EVM test execution, Foundry-compatible cheatcodes, isolated
            hidden evaluation suites, and security exploit defense missions.
          </p>

          <div className="mt-6 flex flex-wrap items-center gap-3">
            <Link
              href="/challenges"
              className="inline-flex items-center gap-2 rounded-md bg-slate-900 px-4 py-2.5 text-sm font-medium text-white hover:bg-slate-800"
            >
              <Code2 className="h-4 w-4" />
              Open Challenge Codex
              <ArrowRight className="h-4 w-4" />
            </Link>
            <Link
              href="/workspace/erc20-token-vault"
              className="inline-flex items-center gap-2 rounded-md border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
            >
              Launch ERC-20 Workspace
            </Link>
            <Link
              href="/security"
              className="inline-flex items-center gap-2 rounded-md border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
            >
              <Shield className="h-4 w-4" />
              Security Arena
            </Link>
          </div>
        </div>

        {/* Verified Platform Inventory (no fabricated metrics) */}
        <div className="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-4">
          <Card className="p-4">
            <div className="text-xs font-medium text-zinc-500">Validated Challenges</div>
            <div className="mt-1 font-mono text-2xl font-semibold text-zinc-950">
              {challenges.length}
            </div>
            <div className="mt-1 text-xs text-zinc-500">EVM public + hidden suites</div>
          </Card>
          <Card className="p-4">
            <div className="text-xs font-medium text-zinc-500">Security Missions</div>
            <div className="mt-1 font-mono text-2xl font-semibold text-zinc-950">
              {securityCount}
            </div>
            <div className="mt-1 text-xs text-zinc-500">Reentrancy, replay & inflation</div>
          </Card>
          <Card className="p-4">
            <div className="text-xs font-medium text-zinc-500">Execution Ecosystems</div>
            <div className="mt-1 font-mono text-2xl font-semibold text-zinc-950">
              {activeExecutionCount} / {ECOSYSTEM_REGISTRY.length}
            </div>
            <div className="mt-1 text-xs text-zinc-500">EVM Level 4 active; 9 mapped</div>
          </Card>
          <Card className="p-4">
            <div className="text-xs font-medium text-zinc-500">Protocol Labs</div>
            <div className="mt-1 font-mono text-2xl font-semibold text-zinc-950">
              {PROTOCOL_LABS.length}
            </div>
            <div className="mt-1 text-xs text-zinc-500">AMM, Vaults & Timelocks</div>
          </Card>
        </div>
      </section>

      {/* Core Modules */}
      <section className="py-10 border-b border-zinc-200">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-zinc-950">Featured Engineering Challenges</h2>
          <Link href="/challenges" className="text-xs font-medium text-blue-700 hover:underline">
            View all {challenges.length} challenges →
          </Link>
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {challenges.slice(0, 6).map((c) => (
            <Card key={c.slug} className="flex flex-col justify-between p-5">
              <div>
                <div className="flex items-center justify-between gap-2">
                  <Badge tone="blue">{c.ecosystem}</Badge>
                  <Badge
                    tone={
                      c.difficulty === "beginner"
                        ? "green"
                        : c.difficulty === "intermediate"
                          ? "amber"
                          : "red"
                    }
                  >
                    {c.difficulty}
                  </Badge>
                </div>
                <h3 className="mt-3 text-base font-semibold text-zinc-950">{c.title}</h3>
                <p className="mt-1.5 text-xs leading-relaxed text-zinc-600 line-clamp-3">
                  {c.description}
                </p>
              </div>
              <div className="mt-4 flex items-center justify-between border-t border-zinc-100 pt-3">
                <span className="font-mono text-xs text-zinc-500">
                  {c.scoring.max_points} pts · {c.language}
                </span>
                <Link
                  href={`/workspace/${c.slug}`}
                  className="text-xs font-medium text-slate-900 hover:text-blue-700"
                >
                  Open IDE →
                </Link>
              </div>
            </Card>
          ))}
        </div>
      </section>

      {/* Ecosystem Support Matrix */}
      <section className="py-10">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold text-zinc-950">
              Multi-Ecosystem Capability Matrix
            </h2>
            <p className="mt-1 text-xs text-zinc-500">
              Support levels are updated strictly after compiler, runner, and integration test
              verification.
            </p>
          </div>
          <Link href="/ecosystems" className="text-xs font-medium text-blue-700 hover:underline">
            Inspect toolchains →
          </Link>
        </div>
        <div className="mt-4 overflow-x-auto rounded-lg border border-zinc-200 bg-white">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
              <tr>
                <th className="px-4 py-3 font-medium">Ecosystem</th>
                <th className="px-4 py-3 font-medium">Languages</th>
                <th className="px-4 py-3 font-medium">Support Level</th>
                <th className="px-4 py-3 font-medium">Adapter</th>
                <th className="px-4 py-3 font-medium">Execution Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {ECOSYSTEM_REGISTRY.map((eco) => {
                const lvl = SUPPORT_LEVEL_LABELS[eco.supportLevel];
                return (
                  <tr key={eco.id} className="hover:bg-zinc-50/70">
                    <td className="px-4 py-3 font-medium text-zinc-950">{eco.name}</td>
                    <td className="px-4 py-3 font-mono text-zinc-600">
                      {eco.primaryLanguages.join(", ")}
                    </td>
                    <td className="px-4 py-3">
                      <Badge tone={eco.supportLevel >= 3 ? "green" : eco.supportLevel === 1 ? "blue" : "neutral"}>
                        L{eco.supportLevel}: {lvl.name}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 font-mono text-zinc-500">{eco.adapterId}</td>
                    <td className="px-4 py-3 text-zinc-600">
                      {eco.capabilities.localCliTest ? (
                        <span className="inline-flex items-center gap-1 text-emerald-700 font-medium">
                          <CheckCircle2 className="h-3.5 w-3.5" />
                          Verified solc + EVM
                        </span>
                      ) : eco.capabilities.editorSyntax ? (
                        <span className="inline-flex items-center gap-1 text-zinc-600">
                          <Cpu className="h-3.5 w-3.5" />
                          Syntax only (Phase 4 runner)
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-zinc-400">
                          <Layers className="h-3.5 w-3.5" />
                          Reference & roadmap
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
