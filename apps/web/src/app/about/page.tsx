import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, Ban, Eye, Lock, Ruler, ShieldCheck, Target } from "lucide-react";
import { ECOSYSTEM_REGISTRY } from "@consinzo/ecosystem-registry";
import { Container, DarkBand, LogoOrb, PageHero, SectionHeading } from "@/components/marketing/blocks";
import { CountUp, Reveal } from "@/components/marketing/motion";
import { listPublishedChallenges } from "@/lib/challenges";
import { pageMetadata } from "@/lib/site";

export const metadata: Metadata = pageMetadata({
  title: "About",
  description:
    "CONSINZO is an engineering platform for smart-contract developers: native compilation, adversarial tests, exploit reproduction and verifiable progress.",
  path: "/about",
});

const PRINCIPLES = [
  {
    icon: Target,
    title: "Real execution or nothing",
    text: "Code is compiled by the real compiler and run on a real VM. If an ecosystem has no verified runner yet, we say so instead of faking a result.",
  },
  {
    icon: ShieldCheck,
    title: "Adversarial by default",
    text: "Passing the visible tests is not enough. Hidden suites probe the invariants an attacker would, so a pass means the contract holds.",
  },
  {
    icon: Ruler,
    title: "Measured, not claimed",
    text: "Scores combine correctness, security invariants, efficiency and code quality. Every number on this site is read from the registry, not written by marketing.",
  },
  {
    icon: Eye,
    title: "Honest support levels",
    text: "Each ecosystem carries a level from 0 to 5. A level only rises after automated integration tests verify the capability.",
  },
];

const NOT = [
  "Multiple-choice quizzes about Solidity trivia",
  "Toy sandboxes that print canned output",
  "Leaderboards you can climb without passing hidden tests",
];

export default function AboutPage() {
  const challenges = listPublishedChallenges();
  const running = ECOSYSTEM_REGISTRY.filter((e) => e.supportLevel >= 3).length;
  const facts = [
    { value: challenges.length, label: "validated challenges" },
    { value: challenges.filter((c) => c.is_security_mission).length, label: "security missions" },
    { value: ECOSYSTEM_REGISTRY.length, label: "ecosystems mapped" },
    { value: running, label: "ecosystems executing code" },
  ];

  return (
    <DarkBand>
      <div className="relative">
        <LogoOrb className="pointer-events-none absolute right-[4%] top-14 hidden w-64 opacity-60 lg:grid" />
        <PageHero
          eyebrow="About CONSINZO"
          title={
            <>
              An engineering platform, <span className="cz-gradient-text">not a quiz</span>
            </>
          }
          lead="CONSINZO exists for developers who want to get good at smart contracts the way engineers get good at anything: by building, testing, breaking and repeating."
        />
      </div>

      <Container className="pb-20">
        <dl className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          {facts.map((f, i) => (
            <Reveal key={f.label} delay={i * 70} className="cz-card p-5">
              <dd className="font-mono text-3xl font-semibold text-white sm:text-4xl">
                <CountUp value={f.value} />
              </dd>
              <dt className="mt-1 text-xs text-zinc-400">{f.label}</dt>
            </Reveal>
          ))}
        </dl>
      </Container>

      <Container className="grid gap-10 pb-20 lg:grid-cols-2 lg:gap-16">
        <Reveal>
          <SectionHeading eyebrow="Why it exists" title="Practice that matches the job" />
          <div className="cz-prose mt-5 text-sm leading-relaxed text-zinc-400 sm:text-base">
            <p>
              Smart contracts are unforgiving. A missed edge case is not a bug ticket, it is lost
              funds. Yet most learning material stops at reading code and answering questions
              about it.
            </p>
            <p>
              CONSINZO centers on native compilation, adversarial testing, security exploit
              reproduction, and verifiable engineering progression. You write the contract, the
              platform runs it, and the result is something you can show.
            </p>
          </div>
        </Reveal>
        <Reveal delay={120} className="cz-card p-6 sm:p-8">
          <h2 className="flex items-center gap-2 text-sm font-semibold text-white">
            <Ban className="h-4 w-4 text-rose-300" />
            What CONSINZO is not
          </h2>
          <ul className="mt-4 space-y-3 text-sm text-zinc-400">
            {NOT.map((n) => (
              <li key={n} className="flex gap-3">
                <span className="mt-2 h-1 w-3 shrink-0 rounded bg-rose-400/60" aria-hidden />
                {n}
              </li>
            ))}
          </ul>
        </Reveal>
      </Container>

      <Container className="pb-20">
        <Reveal>
          <SectionHeading eyebrow="Principles" title="How we decide what to ship" />
        </Reveal>
        <div className="mt-10 grid gap-4 sm:grid-cols-2">
          {PRINCIPLES.map((p, i) => (
            <Reveal key={p.title} delay={(i % 2) * 90} className="cz-card cz-card-hover p-6">
              <p.icon className="h-6 w-6 text-cyan-300" />
              <h3 className="mt-4 text-base font-semibold text-white">{p.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-zinc-400">{p.text}</p>
            </Reveal>
          ))}
        </div>
      </Container>

      <Container className="pb-24">
        <Reveal className="cz-card flex flex-col gap-6 p-6 sm:p-8 lg:flex-row lg:items-center lg:justify-between">
          <div className="max-w-2xl">
            <h2 className="flex items-center gap-2 text-sm font-semibold text-white">
              <Lock className="h-4 w-4 text-violet-300" />
              Proprietary software
            </h2>
            <p className="mt-2 text-sm leading-relaxed text-zinc-400">
              Copyright © 2026 CONSINZO. All rights reserved. Public access to the web platform
              does not grant open-source rights to its source code, evaluation engine, or
              proprietary challenge suites.
            </p>
          </div>
          <div className="flex shrink-0 flex-col gap-3 sm:flex-row">
            <Link href="/challenges" className="cz-btn cz-btn-primary">
              Start building <ArrowRight className="h-4 w-4" />
            </Link>
            <Link href="/contact" className="cz-btn cz-btn-ghost">
              Contact us
            </Link>
          </div>
        </Reveal>
      </Container>
    </DarkBand>
  );
}
