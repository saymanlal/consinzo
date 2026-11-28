import React from "react";
import Link from "next/link";
import { Container, DarkBand, PageHero } from "@/components/marketing/blocks";
import { Reveal } from "@/components/marketing/motion";

const LEGAL_LINKS = [
  { href: "/legal/terms", label: "Terms of Service" },
  { href: "/legal/privacy", label: "Privacy Policy" },
  { href: "/legal/security", label: "Security Policy" },
];

export interface LegalSection {
  heading: string;
  body: React.ReactNode;
}

/** Shared layout for the legal pages: hero, sibling nav, numbered sections. */
export function LegalPage({
  current,
  title,
  lead,
  updated,
  sections,
}: {
  current: string;
  title: string;
  lead: string;
  updated?: string;
  sections: LegalSection[];
}) {
  return (
    <DarkBand>
      <PageHero eyebrow="Legal" title={title} lead={lead}>
        {updated ? (
          <p className="font-mono text-xs text-zinc-500">
            Last updated <time dateTime={updated}>{updated}</time>
          </p>
        ) : null}
      </PageHero>
      <Container className="grid gap-8 pb-24 lg:grid-cols-[14rem_1fr]">
        <nav aria-label="Legal documents" className="lg:sticky lg:top-20 lg:self-start">
          <ul className="flex gap-2 overflow-x-auto lg:flex-col">
            {LEGAL_LINKS.map((l) => (
              <li key={l.href} className="shrink-0">
                <Link
                  href={l.href}
                  aria-current={l.href === current ? "page" : undefined}
                  className={`cz-focus block rounded-lg border px-3 py-2 text-sm ${
                    l.href === current
                      ? "border-white/20 bg-white/10 text-white"
                      : "border-transparent text-zinc-400 hover:text-white"
                  }`}
                >
                  {l.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
        <div className="space-y-4">
          {sections.map((s, i) => (
            <Reveal as="section" key={s.heading} delay={Math.min(i, 3) * 60} className="cz-card p-6 sm:p-8">
              <h2 className="flex items-baseline gap-3 text-base font-semibold text-white">
                <span className="font-mono text-xs text-cyan-300">{String(i + 1).padStart(2, "0")}</span>
                {s.heading}
              </h2>
              <div className="cz-prose mt-3 text-sm leading-relaxed text-zinc-400">{s.body}</div>
            </Reveal>
          ))}
        </div>
      </Container>
    </DarkBand>
  );
}
