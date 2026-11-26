import { Card } from "@consinzo/ui";

export default function PrivacyPolicyPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-10 space-y-4">
      <h1 className="text-2xl font-semibold text-zinc-950">Privacy Policy</h1>
      <Card className="p-6 space-y-3 text-xs leading-relaxed text-zinc-700">
        <p>Last updated: 2026-11-26</p>
        <p>
          CONSINZO collects only the account metadata required for authentication and developer
          progression (email, username, display name, optional GitHub/website links, and challenge
          submission records).
        </p>
        <p>
          Authentication sessions use strictly necessary HTTP-only cookies. No third-party ad
          trackers or data brokers are integrated.
        </p>
      </Card>
    </div>
  );
}
