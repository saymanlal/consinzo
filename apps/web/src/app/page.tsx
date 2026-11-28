import type { Metadata } from "next";
import Link from "next/link";
import {
  ArrowRight,
  BookOpen,
  CheckCircle2,
  Code2,
  Cpu,
  FlaskConical,
  GraduationCap,
  Hammer,
  Layers,
  Shield,
  Swords,
  Trophy,
  Zap,
} from "lucide-react";
import { ECOSYSTEM_REGISTRY, SUPPORT_LEVEL_LABELS } from "@consinzo/ecosystem-registry";
import { DifficultyBadge } from "@/components/difficulty-badge";
import {
  Container,
  DarkBand,
  Eyebrow,
  LogoOrb,
  SectionHeading,
} from "@/components/marketing/blocks";
import { CountUp, Reveal, TerminalDemo, type TerminalLine } from "@/components/marketing/motion";
import { JsonLd } from "@/components/json-ld";
import { describeSignInMethods } from "@/lib/auth-methods";
import { listPublishedChallenges } from "@/lib/challenges";
import { GUEST_LIMITS } from "@/lib/guest-limits";
import { DIFFICULTY_META, DIFFICULTY_TIERS, normalizeDifficulty } from "@/lib/difficulty";
import { KNOWLEDGE_ENTRIES, PROTOCOL_LABS } from "@/lib/knowledge";

export const metadata: Metadata = { alternates: { canonical: "/" }, openGraph: { url: "/" } };

const TERMINAL_LINES: TerminalLine[] = [
  { text: "consinzo test erc20-token-vault", tone: "cmd" },
  { text: "Compiling 2 files with solc 0.8.28 … done", tone: "muted" },
  { text: "[PASS] testMetadata()", tone: "ok" },
  { text: "[PASS] testMintAndTransfer()", tone: "ok" },
  { text: "[PASS] testApproveAndTransferFrom()", tone: "ok" },
  { text: "[PASS] testBurnReducesSupply()", tone: "ok" },
  { text: "Public suite 4/4 · hidden suite evaluated on submit", tone: "accent" },
  { text: "consinzo submit", tone: "cmd" },
  { text: "Score = correctness + invariants + efficiency + quality", tone: "muted" },
  { text: "✔ Verified pass — reference solution unlocked", tone: "ok" },
];

const PILLARS = [
  {
    icon: Hammer,
    word: "Build",
    text: "Write real contracts in a browser IDE against a starter project and a written specification.",
  },
  {
    icon: FlaskConical,
    word: "Test",
    text: "Run the public test suite on a real compiler and VM. No multiple-choice, no mocked output.",
  },
  {
    icon: Swords,
    word: "Break",
    text: "Security missions hand you vulnerable code. Reproduce the exploit, then patch it so it holds.",
  },
  {
    icon: Trophy,
    word: "Master",
    text: "Submit for hidden-suite evaluation, earn points and badges, and climb the leaderboards.",
  },
];

const MODULES = [
  {
    href: "/challenges",
    icon: Code2,
    title: "Challenge Codex",
    text: "Engineering challenges from first contracts to protocol design, each with public and hidden suites.",
  },
  {
    href: "/security",
    icon: Shield,
    title: "Security Arena",
    text: "Exploit-and-patch missions across reentrancy, replay, oracle manipulation, upgrade auth and more.",
  },
  {
    href: "/protocols",
    icon: Layers,
    title: "Protocol Lab",
    text: "Interactive simulators for AMMs, tokenized vaults, auctions and flash loans, with their invariants.",
  },
  {
    href: "/ecosystems",
    icon: Cpu,
    title: "Ecosystem Hub",
    text: "Ten ecosystems with pinned toolchains and an honest support level for each one.",
  },
  {
    href: "/knowledge",
    icon: BookOpen,
    title: "Knowledge Hub",
    text: "Version-pinned reference notes with sources, linked to the challenges that exercise them.",
  },
  {
    href: "/academy",
    icon: GraduationCap,
    title: "Academy",
    text: "Guided tracks that order the challenges into a path, with progress you can see.",
  },
];

export default function OverviewPage() {
  const challenges = listPublishedChallenges();
  const securityCount = challenges.filter((c) => c.is_security_mission).length;
  const activeExecution = ECOSYSTEM_REGISTRY.filter((e) => e.supportLevel >= 3);

  const featuredSlugs = [
    "erc20-token-vault",
    "reentrancy-vault-defense",
    "constant-product-amm",
    "erc4626-tokenized-vault",
    "near-counter-contract",
    "near-signer-predecessor-bypass",
  ];
  const featured = featuredSlugs
    .map((slug) => challenges.find((c) => c.slug === slug))
    .filter((c): c is NonNullable<typeof c> => Boolean(c));
  const featuredChallenges = featured.length >= 6 ? featured : challenges.slice(0, 6);

  const tierCounts = DIFFICULTY_TIERS.map((tier) => ({
    tier,
    count: challenges.filter((c) => normalizeDifficulty(c.difficulty) === tier).length,
  }));

  const signIn = describeSignInMethods();
  const runningNames = activeExecution
    .map((e) => `${e.primaryLanguages[0]} on ${e.name}`)
    .join(" and ");
  const guestTiers = GUEST_LIMITS.TIERS.map((t) => DIFFICULTY_META[t].label).join(", ");
  const faqs = [
    {
      q: "What is CONSINZO?",
      a: `CONSINZO is an engineering platform for smart-contract developers. You write real contracts in a browser IDE, the platform compiles and runs them against public tests, and submissions are scored against hidden test suites. It currently has ${challenges.length} validated challenges, ${securityCount} of them security missions.`,
    },
    {
      q: "Which languages and blockchains can I practise?",
      a: `Code runs today for ${runningNames}. ${ECOSYSTEM_REGISTRY.length - activeExecution.length} more ecosystems are mapped with their toolchains and an honest support level, and are not runnable yet.`,
    },
    {
      q: "Do I need an account or a wallet to try it?",
      a: `No. Guest mode lets you open a workspace and run the public tests for ${guestTiers} challenges, up to ${GUEST_LIMITS.RUNS_PER_HOUR} runs an hour. To submit for scoring, earn points and badges, and unlock every tier, create an account with ${signIn}.`,
    },
    {
      q: "I do not have a crypto wallet. Can I still sign up with one?",
      a: "Yes. CONSINZO can create a wallet for you in your browser. You get a standard 12-word recovery phrase that stays on your device; CONSINZO never receives it. Signing in only signs a message. It is not a transaction and costs no gas.",
    },
    {
      q: "How is my solution checked?",
      a: "Your code is compiled with the real compiler and executed on a real virtual machine. Public tests run whenever you ask. On submit, a hidden suite runs on the server and the score combines functional correctness, security invariants, efficiency and code quality.",
    },
    {
      q: "What do the difficulty levels mean?",
      a: `There are six tiers: ${DIFFICULTY_TIERS.map((t) => DIFFICULTY_META[t].label).join(", ")}. Beginner covers first contracts and single invariants; Legend covers multi-contract systems and exploit chains at audit depth.`,
    },
  ];

  const stats = [
    { label: "Validated challenges", value: challenges.length, note: "public + hidden suites" },
    { label: "Security missions", value: securityCount, note: "exploit and patch" },
    {
      label: "Executing ecosystems",
      value: activeExecution.length,
      note: activeExecution.map((e) => e.shortName).join(" + "),
    },
    { label: "Knowledge entries", value: KNOWLEDGE_ENTRIES.length, note: "sourced and versioned" },
  ];

  return (
    <DarkBand>
      {/* ── Hero ── */}
      <Container className="grid items-center gap-12 pb-16 pt-14 sm:pt-20 lg:grid-cols-[1.05fr_0.95fr] lg:pb-24 lg:pt-28">
        <div className="min-w-0">
          <Reveal>
            <Eyebrow>The Engineering Platform</Eyebrow>
          </Reveal>
          <Reveal delay={80}>
            <h1 className="mt-6 text-[2.6rem] font-semibold leading-[1.05] tracking-tight text-white sm:text-6xl lg:text-7xl">
              Build. Test.
              <br />
              <span className="cz-gradient-text">Break. Master.</span>
            </h1>
          </Reveal>
          <Reveal delay={160}>
            <p className="mt-6 max-w-xl text-base leading-relaxed text-zinc-400 sm:text-lg">
              Smart-contract engineering you can actually run. Real{" "}
              <code className="rounded bg-white/10 px-1.5 py-0.5 font-mono text-sm text-zinc-200">
                solc 0.8.28
              </code>{" "}
              compilation, EVM and NEAR test execution, hidden evaluation suites, and security
              missions where you break the contract before you fix it.
            </p>
          </Reveal>
          <Reveal delay={240}>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:flex-wrap">
              <Link href="/challenges" className="cz-btn cz-btn-primary">
                <Code2 className="h-4 w-4" />
                Open the Codex
                <ArrowRight className="h-4 w-4" />
              </Link>
              <Link href="/workspace/erc20-token-vault" className="cz-btn cz-btn-ghost">
                <Zap className="h-4 w-4 text-cyan-300" />
                Try it without an account
              </Link>
              <Link href="/security" className="cz-btn cz-btn-ghost">
                <Shield className="h-4 w-4 text-violet-300" />
                Security Arena
              </Link>
            </div>
          </Reveal>
          <Reveal delay={320}>
            <p className="mt-5 text-xs text-zinc-500">
              Guest mode runs public tests in your browser session. Sign in to submit, score and
              earn badges.
            </p>
          </Reveal>
        </div>

        <Reveal delay={200} className="relative min-w-0">
          <LogoOrb className="pointer-events-none absolute -right-10 -top-24 hidden w-72 opacity-70 lg:grid" />
          <div className="relative lg:mt-24">
            <TerminalDemo lines={TERMINAL_LINES} title="erc20-token-vault — example run" />
          </div>
        </Reveal>
      </Container>

      {/* ── Verified inventory ── */}
      <Container>
        <dl className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          {stats.map((s, i) => (
            <Reveal key={s.label} delay={i * 70} className="cz-card p-5">
              <dt className="text-xs text-zinc-400">{s.label}</dt>
              <dd className="mt-2 font-mono text-3xl font-semibold text-white sm:text-4xl">
                <CountUp value={s.value} />
              </dd>
              <p className="mt-1 text-xs text-zinc-500">{s.note}</p>
            </Reveal>
          ))}
        </dl>
        <p className="mt-3 text-xs text-zinc-600">
          Counts are read from the live challenge registry at build time, not marketing estimates.
        </p>
      </Container>

      {/* ── Ecosystem marquee ── */}
      <div className="mt-16 border-y border-white/10 py-5" aria-hidden>
        <div className="cz-marquee">
          {[0, 1].map((dup) => (
            <div key={dup} className="cz-marquee-track">
              {ECOSYSTEM_REGISTRY.map((eco) => (
                <span
                  key={`${dup}-${eco.id}`}
                  className="inline-flex items-center gap-2 whitespace-nowrap rounded-full border border-white/10 bg-white/[0.03] px-4 py-2 text-xs text-zinc-300"
                >
                  <span
                    className={`h-1.5 w-1.5 rounded-full ${
                      eco.supportLevel >= 3 ? "bg-emerald-400" : "bg-zinc-600"
                    }`}
                  />
                  {eco.name}
                  <span className="font-mono text-zinc-500">
                    {eco.primaryLanguages[0]} · L{eco.supportLevel}
                  </span>
                </span>
              ))}
            </div>
          ))}
        </div>
      </div>

      {/* ── Four verbs ── */}
      <Container className="py-20 sm:py-24">
        <Reveal>
          <SectionHeading
            eyebrow="How it works"
            title="Four verbs, one loop"
            lead="Every challenge follows the same path, so the habit you build is the one audits and production demand."
          />
        </Reveal>
        <ol className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {PILLARS.map((p, i) => (
            <Reveal as="li" key={p.word} delay={i * 90} className="cz-card cz-card-hover p-6">
              <div className="flex items-center justify-between">
                <span className="grid h-10 w-10 place-items-center rounded-xl border border-white/10 bg-white/5">
                  <p.icon className="h-5 w-5 text-cyan-300" />
                </span>
                <span className="font-mono text-xs text-zinc-600">0{i + 1}</span>
              </div>
              <h3 className="mt-5 text-lg font-semibold text-white">{p.word}</h3>
              <p className="mt-2 text-sm leading-relaxed text-zinc-400">{p.text}</p>
            </Reveal>
          ))}
        </ol>
      </Container>

      {/* ── Modules ── */}
      <Container className="pb-20 sm:pb-24">
        <Reveal>
          <SectionHeading
            eyebrow="The platform"
            title="Everything in one workspace"
            lead="Six connected modules. Pick a door; they all lead to code you run."
          />
        </Reveal>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {MODULES.map((m, i) => (
            <Reveal key={m.href} delay={(i % 3) * 90}>
              <Link href={m.href} className="cz-card cz-card-hover cz-focus group block h-full p-6">
                <m.icon className="h-6 w-6 text-violet-300" />
                <h3 className="mt-4 flex items-center gap-2 text-base font-semibold text-white">
                  {m.title}
                  <ArrowRight className="h-4 w-4 -translate-x-1 text-cyan-300 opacity-0 transition group-hover:translate-x-0 group-hover:opacity-100" />
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-zinc-400">{m.text}</p>
              </Link>
            </Reveal>
          ))}
        </div>
      </Container>

      {/* ── Difficulty ladder ── */}
      <Container className="pb-20 sm:pb-24">
        <Reveal>
          <SectionHeading
            eyebrow="Difficulty ladder"
            title="Six tiers, from first contract to legend"
            lead="Filter the Codex by tier and climb at your own pace."
          />
        </Reveal>
        <div className="mt-10 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {tierCounts.map(({ tier, count }, i) => {
            const meta = DIFFICULTY_META[tier];
            return (
              <Reveal key={tier} delay={(i % 3) * 80}>
                <Link
                  href={`/challenges?difficulty=${tier}`}
                  className="cz-card cz-card-hover cz-focus flex h-full items-start gap-4 p-5"
                >
                  <span className="font-mono text-2xl font-semibold text-zinc-700">
                    {meta.rank}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center justify-between gap-2">
                      <DifficultyBadge difficulty={tier} surface="dark" />
                      <span className="font-mono text-xs text-zinc-500">
                        {count} {count === 1 ? "challenge" : "challenges"}
                      </span>
                    </span>
                    <span className="mt-2 block text-sm leading-relaxed text-zinc-400">
                      {meta.blurb}
                    </span>
                  </span>
                </Link>
              </Reveal>
            );
          })}
        </div>
      </Container>

      {/* ── Featured ── */}
      <Container className="pb-20 sm:pb-24">
        <Reveal className="flex flex-wrap items-end justify-between gap-4">
          <SectionHeading eyebrow="Start here" title="Featured challenges" />
          <Link
            href="/challenges"
            className="cz-focus rounded text-sm font-medium text-cyan-300 hover:text-white"
          >
            View all {challenges.length} →
          </Link>
        </Reveal>
        <div className="mt-8 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {featuredChallenges.map((c, i) => (
            <Reveal key={c.slug} delay={(i % 3) * 90}>
              <article className="cz-card cz-card-hover flex h-full flex-col justify-between p-6">
                <div>
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="rounded border border-white/10 bg-white/5 px-2 py-0.5 font-mono text-[11px] text-zinc-300">
                      {c.ecosystem}
                    </span>
                    <DifficultyBadge difficulty={c.difficulty} surface="dark" />
                  </div>
                  <h3 className="mt-4 text-base font-semibold text-white">
                    <Link href={`/challenges/${c.slug}`} className="cz-focus rounded hover:underline">
                      {c.title}
                    </Link>
                  </h3>
                  <p className="mt-2 line-clamp-3 text-sm leading-relaxed text-zinc-400">
                    {c.description}
                  </p>
                </div>
                <div className="mt-5 flex items-center justify-between border-t border-white/10 pt-4">
                  <span className="font-mono text-xs text-zinc-500">
                    {c.scoring.max_points} pts · {c.language}
                  </span>
                  <Link
                    href={`/workspace/${c.slug}`}
                    className="cz-focus rounded text-xs font-semibold text-white hover:text-cyan-300"
                  >
                    Open IDE →
                  </Link>
                </div>
              </article>
            </Reveal>
          ))}
        </div>
      </Container>

      {/* ── Ecosystem matrix ── */}
      <Container className="pb-20 sm:pb-24">
        <Reveal className="flex flex-wrap items-end justify-between gap-4">
          <SectionHeading
            eyebrow="Ecosystems"
            title="An honest capability matrix"
            lead="A support level only moves after the compiler, runner and integration tests are verified."
          />
          <Link
            href="/ecosystems"
            className="cz-focus rounded text-sm font-medium text-cyan-300 hover:text-white"
          >
            Inspect toolchains →
          </Link>
        </Reveal>
        <Reveal delay={100} className="cz-card mt-8 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[640px] text-left text-sm">
              <thead className="border-b border-white/10 text-xs text-zinc-500">
                <tr>
                  <th scope="col" className="px-5 py-3 font-medium">Ecosystem</th>
                  <th scope="col" className="px-5 py-3 font-medium">Languages</th>
                  <th scope="col" className="px-5 py-3 font-medium">Support level</th>
                  <th scope="col" className="px-5 py-3 font-medium">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {ECOSYSTEM_REGISTRY.map((eco) => {
                  const lvl = SUPPORT_LEVEL_LABELS[eco.supportLevel];
                  return (
                    <tr key={eco.id} className="transition-colors hover:bg-white/[0.03]">
                      <th scope="row" className="px-5 py-3 font-medium text-white">{eco.name}</th>
                      <td className="px-5 py-3 font-mono text-xs text-zinc-400">
                        {eco.primaryLanguages.join(", ")}
                      </td>
                      <td className="px-5 py-3">
                        <span
                          className={`inline-flex rounded border px-2 py-0.5 text-xs font-medium ${
                            eco.supportLevel >= 3
                              ? "border-emerald-400/30 bg-emerald-400/10 text-emerald-300"
                              : eco.supportLevel === 1
                                ? "border-sky-400/30 bg-sky-400/10 text-sky-300"
                                : "border-white/10 bg-white/5 text-zinc-400"
                          }`}
                        >
                          L{eco.supportLevel} · {lvl.name}
                        </span>
                      </td>
                      <td className="px-5 py-3 text-xs">
                        {eco.capabilities.localCliTest ? (
                          <span className="inline-flex items-center gap-1.5 font-medium text-emerald-300">
                            <CheckCircle2 className="h-3.5 w-3.5" />
                            Compiles and runs tests
                          </span>
                        ) : eco.capabilities.editorSyntax ? (
                          <span className="text-zinc-400">Editor syntax only</span>
                        ) : (
                          <span className="text-zinc-600">Reference only</span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Reveal>
      </Container>

      {/* ── FAQ ── */}
      <Container className="pb-20 sm:pb-24">
        <Reveal>
          <SectionHeading eyebrow="FAQ" title="Questions people ask first" />
        </Reveal>
        <div className="mt-8 grid gap-3 lg:grid-cols-2">
          {faqs.map((f, i) => (
            <Reveal key={f.q} delay={(i % 2) * 80}>
              <details className="cz-card group p-5 open:border-white/20">
                <summary className="cz-focus flex cursor-pointer list-none items-start justify-between gap-4 rounded text-sm font-semibold text-white [&::-webkit-details-marker]:hidden">
                  <h3>{f.q}</h3>
                  <span aria-hidden className="mt-0.5 text-lg leading-none text-cyan-300 transition-transform group-open:rotate-45">
                    +
                  </span>
                </summary>
                <p className="mt-3 text-sm leading-relaxed text-zinc-400">{f.a}</p>
              </details>
            </Reveal>
          ))}
        </div>
        <JsonLd
          data={{
            "@context": "https://schema.org",
            "@type": "FAQPage",
            mainEntity: faqs.map((f) => ({
              "@type": "Question",
              name: f.q,
              acceptedAnswer: { "@type": "Answer", text: f.a },
            })),
          }}
        />
      </Container>

      {/* ── CTA ── */}
      <Container className="pb-24">
        <Reveal className="cz-card relative overflow-hidden px-6 py-12 text-center sm:px-12 sm:py-16">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-x-0 -top-24 mx-auto h-48 w-2/3 rounded-full bg-cyan-400/20 blur-3xl"
          />
          <h2 className="relative text-3xl font-semibold tracking-tight text-white sm:text-4xl">
            Your first passing test is one click away
          </h2>
          <p className="relative mx-auto mt-3 max-w-xl text-sm leading-relaxed text-zinc-400 sm:text-base">
            Open a workspace as a guest, or create an account with {signIn} to keep your score.{" "}
            {PROTOCOL_LABS.length} protocol labs are waiting too.
          </p>
          <div className="relative mt-8 flex flex-col justify-center gap-3 sm:flex-row">
            <Link href="/auth?mode=register" className="cz-btn cz-btn-primary">
              Create account
              <ArrowRight className="h-4 w-4" />
            </Link>
            <Link href="/workspace/erc20-token-vault" className="cz-btn cz-btn-ghost">
              Continue as guest
            </Link>
          </div>
        </Reveal>
      </Container>
    </DarkBand>
  );
}
