import { listPublishedChallenges } from "@/lib/challenges";
import { ChallengeCatalogueClient } from "@/components/challenge-catalogue";
import { GuestNotice } from "@/components/guest-notice";

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
      <ChallengeCatalogueClient initialChallenges={challenges} />
    </div>
  );
}
