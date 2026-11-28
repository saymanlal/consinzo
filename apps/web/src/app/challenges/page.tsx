import type { Metadata } from "next";
import { pageMetadata } from "@/lib/site";
import { listPublishedChallenges } from "@/lib/challenges";
import { ChallengeCatalogueClient } from "@/components/challenge-catalogue";
import { GuestNotice } from "@/components/guest-notice";

export const metadata: Metadata = pageMetadata({
  title: "Smart Contract Challenges",
  description:
    "Browse validated smart-contract engineering challenges in Solidity and NEAR TypeScript. Filter by six difficulty tiers, language, category and type, then solve in the browser IDE.",
  path: "/challenges",
});

export default function ChallengesPage() {
  const challenges = listPublishedChallenges();

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6">
      <div className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-950">
          Codex Challenge Catalogue
        </h1>
        <p className="mt-1 text-sm text-zinc-600">
          Validated smart contract engineering challenges with starter projects, real Solidity and
          NEAR TypeScript compilation, and isolated evaluation tests.
        </p>
      </div>
      <GuestNotice />
      <ChallengeCatalogueClient
        initialChallenges={challenges.map((c) => ({
          slug: c.slug,
          title: c.title,
          description: c.description,
          ecosystem: c.ecosystem,
          language: c.language,
          difficulty: c.difficulty,
          category: c.category,
          tags: c.tags,
          is_security_mission: c.is_security_mission,
          max_points: c.scoring.max_points,
        }))}
      />
    </div>
  );
}
