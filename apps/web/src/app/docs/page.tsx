import type { Metadata } from "next";
import Link from "next/link";
import { Gauge, PlayCircle, Terminal, UserRound } from "lucide-react";
import { FREE_TIER_LIMITS } from "@consinzo/shared";
import { Container, DarkBand, PageHero } from "@/components/marketing/blocks";
import { Reveal } from "@/components/marketing/motion";
import { DIFFICULTY_META, DIFFICULTY_TIERS } from "@/lib/difficulty";
import { GUEST_LIMITS } from "@/lib/guest-limits";
import { pageMetadata } from "@/lib/site";

export const metadata: Metadata = pageMetadata({
  title: "Documentation",
  description:
    "CONSINZO technical documentation: execution modes, the local CLI, guest and account limits, difficulty tiers and scoring.",
  path: "/docs",
});

const kb = (bytes: number) => `${Math.round(bytes / 1024)} KB`;

export default function DocsPage() {
  return (
    <DarkBand>
      <PageHero
        eyebrow="Documentation"
        title={
          <>
            How CONSINZO <span className="cz-gradient-text">runs your code</span>
          </>
        }
        lead="Execution modes, the local CLI, limits for guests and accounts, difficulty tiers and scoring."
      />
      <Container className="grid gap-4 pb-24 lg:grid-cols-2">
        <Reveal as="section" className="cz-card p-6 sm:p-8 lg:col-span-2">
          <h2 className="flex items-center gap-2 text-base font-semibold text-white">
            <PlayCircle className="h-5 w-5 text-cyan-300" /> Execution modes
          </h2>
          <ul className="mt-4 space-y-4 text-sm leading-relaxed text-zinc-400">
            <li>
              <strong className="text-zinc-200">Mode B — local CLI and in-process runners.</strong>{" "}
              Compiles EVM Solidity projects with <code className="font-mono text-zinc-200">solc 0.8.28</code>{" "}
              and executes Foundry-compatible test contracts with native{" "}
              <code className="font-mono text-zinc-200">forge</code> (when installed) or the bundled{" "}
              <code className="font-mono text-zinc-200">@ethereumjs/evm</code>. NEAR TypeScript
              contracts are type-checked and executed by{" "}
              <code className="font-mono text-zinc-200">@consinzo/runner-near</code>.
            </li>
            <li>
              <strong className="text-zinc-200">Mode C — remote evaluation.</strong> Disabled by
              default unless an isolated evaluation runner without repository secret exposure is
              configured.
            </li>
          </ul>
        </Reveal>

        <Reveal as="section" delay={80} className="cz-card p-6 sm:p-8">
          <h2 className="flex items-center gap-2 text-base font-semibold text-white">
            <Terminal className="h-5 w-5 text-violet-300" /> Local CLI
          </h2>
          <pre className="mt-4 overflow-x-auto rounded-xl border border-white/10 bg-black/50 p-4 font-mono text-xs leading-relaxed text-zinc-300">
{`pnpm cli -- doctor
pnpm cli -- compile content/challenges/erc20-token-vault
pnpm cli -- test content/challenges/erc20-token-vault
pnpm validate:challenges`}
          </pre>
        </Reveal>

        <Reveal as="section" delay={140} className="cz-card p-6 sm:p-8">
          <h2 className="flex items-center gap-2 text-base font-semibold text-white">
            <Gauge className="h-5 w-5 text-emerald-300" /> Limits for accounts
          </h2>
          <ul className="mt-4 space-y-2 text-sm text-zinc-400">
            <li>Project snapshot: {kb(FREE_TIER_LIMITS.MAX_PROJECT_BYTES)} across up to {FREE_TIER_LIMITS.MAX_FILES_PER_SNAPSHOT} files.</li>
            <li>Execution timeout: {(FREE_TIER_LIMITS.MAX_EXECUTION_DURATION_MS / 1000).toLocaleString("en-US")} s per run; logs capped at {kb(FREE_TIER_LIMITS.MAX_OUTPUT_BYTES)}.</li>
            <li>Submissions: {FREE_TIER_LIMITS.MAX_SUBMISSIONS_PER_HOUR} per hour.</li>
          </ul>
        </Reveal>

        <Reveal as="section" delay={80} className="cz-card p-6 sm:p-8">
          <h2 className="flex items-center gap-2 text-base font-semibold text-white">
            <UserRound className="h-5 w-5 text-amber-300" /> Guest mode
          </h2>
          <p className="mt-4 text-sm leading-relaxed text-zinc-400">
            Open any workspace without an account and run the public tests. Guests get{" "}
            {GUEST_LIMITS.RUNS_PER_HOUR} runs per hour. Submitting for hidden-suite scoring,
            points, badges, solutions, bookmarks and competitions need an account.{" "}
            <Link href="/auth?mode=register" className="cz-focus rounded text-zinc-200 underline hover:text-white">
              Create one
            </Link>
            .
          </p>
        </Reveal>

        <Reveal as="section" delay={140} className="cz-card p-6 sm:p-8">
          <h2 className="text-base font-semibold text-white">Difficulty tiers</h2>
          <ol className="mt-4 space-y-2 text-sm text-zinc-400">
            {DIFFICULTY_TIERS.map((t) => (
              <li key={t} className="flex gap-3">
                <span className={`mt-1.5 h-2 w-2 shrink-0 rounded-full ${DIFFICULTY_META[t].dot}`} aria-hidden />
                <span>
                  <strong className="text-zinc-200">{DIFFICULTY_META[t].label}.</strong>{" "}
                  {DIFFICULTY_META[t].blurb}
                </span>
              </li>
            ))}
          </ol>
        </Reveal>
      </Container>
    </DarkBand>
  );
}
