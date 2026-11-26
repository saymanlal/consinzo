import { Card } from "@consinzo/ui";

export default function TermsPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-10 space-y-4">
      <h1 className="text-2xl font-semibold text-zinc-950">Terms of Service & Intellectual Property</h1>
      <Card className="p-6 space-y-3 text-xs leading-relaxed text-zinc-700">
        <p>Last updated: 2026-11-26</p>
        <p>
          CONSINZO and all proprietary challenge specifications, hidden evaluation suites, reference
          solutions, platform code, and security missions remain the exclusive intellectual property
          of CONSINZO.
        </p>
        <p>
          Authorized users may submit code solutions for personal learning and competition
          participation. Redistributing hidden tests, scraping solutions, or attempting to probe or
          escape evaluation runners is strictly prohibited.
        </p>
      </Card>
    </div>
  );
}
