import React from "react";
import { BrandMark } from "@/components/brand-logo";

/** Full-bleed dark band with the animated aurora + grid backdrop. */
export function DarkBand({
  children,
  className = "",
  aurora = true,
}: {
  children: React.ReactNode;
  className?: string;
  aurora?: boolean;
}) {
  return (
    <div className={`cz-dark ${aurora ? "cz-aurora" : ""} ${className}`}>
      {aurora ? <div className="cz-grid" aria-hidden /> : null}
      {children}
    </div>
  );
}

export function Container({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return <div className={`mx-auto w-full max-w-[1200px] px-5 sm:px-6 ${className}`}>{children}</div>;
}

export function Eyebrow({ children }: { children: React.ReactNode }) {
  return (
    <span className="cz-eyebrow">
      <span className="cz-pulse-dot" aria-hidden />
      {children}
    </span>
  );
}

export function SectionHeading({
  eyebrow,
  title,
  lead,
  align = "left",
}: {
  eyebrow?: string;
  title: React.ReactNode;
  lead?: React.ReactNode;
  align?: "left" | "center";
}) {
  return (
    <div className={align === "center" ? "mx-auto max-w-2xl text-center" : "max-w-2xl"}>
      {eyebrow ? (
        <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-cyan-300">{eyebrow}</p>
      ) : null}
      <h2 className="mt-2 text-2xl font-semibold tracking-tight text-white sm:text-3xl">{title}</h2>
      {lead ? <p className="mt-3 text-sm leading-relaxed text-zinc-400 sm:text-base">{lead}</p> : null}
    </div>
  );
}

/** Compact hero used by About, Contact, Docs and the legal pages. */
export function PageHero({
  eyebrow,
  title,
  lead,
  children,
}: {
  eyebrow: string;
  title: React.ReactNode;
  lead: React.ReactNode;
  children?: React.ReactNode;
}) {
  return (
    <Container className="pb-14 pt-16 sm:pb-20 sm:pt-24">
      <Eyebrow>{eyebrow}</Eyebrow>
      <h1 className="mt-5 max-w-3xl text-4xl font-semibold tracking-tight text-white sm:text-5xl">
        {title}
      </h1>
      <p className="mt-4 max-w-2xl text-base leading-relaxed text-zinc-400 sm:text-lg">{lead}</p>
      {children ? <div className="mt-8">{children}</div> : null}
    </Container>
  );
}

/** The mark inside counter-rotating rings. Decorative. */
export function LogoOrb({ className = "" }: { className?: string }) {
  const nodes = [0, 72, 144, 216, 288];
  return (
    <div className={`cz-orb ${className}`} aria-hidden>
      <div className="cz-orb-ring">
        {nodes.map((deg) => (
          <span key={deg} className="cz-orb-spoke" style={{ transform: `rotate(${deg}deg)` }}>
            <span className="cz-orb-node" />
          </span>
        ))}
      </div>
      <div className="cz-orb-ring" />
      <div className="cz-orb-ring" />
      <BrandMark className="cz-orb-core text-white" />
    </div>
  );
}
