import type { Metadata } from "next";
import { Suspense } from "react";
import { AuthPanel } from "@/components/auth-panel";
import { Container, DarkBand, LogoOrb } from "@/components/marketing/blocks";
import { pageMetadata } from "@/lib/site";

export const metadata: Metadata = pageMetadata({
  title: "Sign in or create an account",
  description:
    "Sign in to CONSINZO with a wallet, Google, GitHub, email or phone. No wallet yet? Create one in your browser in seconds.",
  path: "/auth",
});

const POINTS = [
  "Sign in with a wallet, Google, GitHub, email or phone",
  "No wallet? Create one here. Your recovery phrase never leaves your device",
  "Keep your scores, badges and solved challenges in one profile",
];

export default function AuthPage() {
  return (
    <DarkBand className="min-h-[calc(100dvh-3.5rem)]">
      <Container className="grid items-start gap-10 py-10 sm:py-16 lg:grid-cols-[1fr_28rem] lg:gap-16">
        <div className="hidden lg:block">
          <LogoOrb className="w-56 opacity-80" />
          <h1 className="mt-10 text-4xl font-semibold tracking-tight text-white">
            Your engineering identity, <span className="cz-gradient-text">your way</span>
          </h1>
          <ul className="mt-6 space-y-3 text-sm text-zinc-400">
            {POINTS.map((p) => (
              <li key={p} className="flex gap-3">
                <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-cyan-400" aria-hidden />
                {p}
              </li>
            ))}
          </ul>
        </div>
        <Suspense
          fallback={<div className="cz-card p-8 text-center text-sm text-zinc-500">Loading…</div>}
        >
          <AuthPanel />
        </Suspense>
      </Container>
    </DarkBand>
  );
}
