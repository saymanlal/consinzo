import Link from "next/link";
import { notFound } from "next/navigation";
import { Award, CheckCircle2, ExternalLink, Github, Shield, Trophy } from "lucide-react";
import { DifficultyBadge } from "@/components/difficulty-badge";
import { Badge, Card } from "@consinzo/ui";
import { getAchievementMeta } from "@/lib/achievements";
import { getPublicDeveloperPortfolio } from "@/lib/data-adapter";

export const dynamic = "force-dynamic";

export default async function PublicDeveloperProfilePage({
  params,
}: {
  params: Promise<{ username: string }>;
}) {
  const { username } = await params;
  const portfolio = await getPublicDeveloperPortfolio(username);
  if (!portfolio) notFound();

  return (
    <div className="mx-auto max-w-5xl px-4 py-8 lg:px-6 space-y-8">
      <Card className="p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold text-zinc-950">{portfolio.displayName}</h1>
            <p className="font-mono text-xs text-zinc-500">
              @{portfolio.username} · Joined {new Date(portfolio.joinedAt).toLocaleDateString()}
            </p>
            {portfolio.bio && (
              <p className="mt-3 max-w-2xl text-sm text-zinc-700">{portfolio.bio}</p>
            )}
          </div>

          <div className="flex flex-wrap gap-2">
            {portfolio.githubUrl && (
              <a
                href={portfolio.githubUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1.5 rounded-md border border-zinc-200 px-3 py-1.5 text-xs font-medium text-zinc-800 hover:bg-zinc-50"
              >
                <Github className="h-3.5 w-3.5" />
                GitHub
              </a>
            )}
            {portfolio.websiteUrl && (
              <a
                href={portfolio.websiteUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1.5 rounded-md border border-zinc-200 px-3 py-1.5 text-xs font-medium text-zinc-800 hover:bg-zinc-50"
              >
                <ExternalLink className="h-3.5 w-3.5" />
                Website
              </a>
            )}
          </div>
        </div>

        <div className="mt-6 grid grid-cols-2 gap-4 border-t border-zinc-100 pt-5 sm:grid-cols-4">
          <div>
            <div className="text-xs text-zinc-500">Verified Score</div>
            <div className="mt-1 font-mono text-xl font-semibold text-zinc-950">
              {portfolio.totalPoints}
            </div>
          </div>
          <div>
            <div className="text-xs text-zinc-500">Challenges Passed</div>
            <div className="mt-1 font-mono text-xl font-semibold text-zinc-950">
              {portfolio.challengesCompleted}
            </div>
          </div>
          <div>
            <div className="text-xs text-zinc-500">Security Missions</div>
            <div className="mt-1 font-mono text-xl font-semibold text-zinc-950">
              {portfolio.securityMissionsCompleted}
            </div>
          </div>
          <div>
            <div className="text-xs text-zinc-500">Achievements</div>
            <div className="mt-1 font-mono text-xl font-semibold text-zinc-950">
              {portfolio.achievements.length}
            </div>
          </div>
        </div>
      </Card>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2 p-6">
          <h2 className="text-sm font-semibold text-zinc-950 flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-emerald-700" />
            Verified Challenge Completions ({portfolio.completedChallenges.length})
          </h2>
          <div className="mt-4 space-y-2">
            {portfolio.completedChallenges.length === 0 ? (
              <p className="text-xs text-zinc-500">No verified challenge completions yet.</p>
            ) : (
              portfolio.completedChallenges.map((c) => (
                <Link
                  key={c.slug}
                  href={`/challenges/${c.slug}`}
                  className="flex items-center justify-between rounded border border-zinc-200 px-3 py-2.5 text-xs hover:bg-zinc-50"
                >
                  <div>
                    <div className="font-medium text-zinc-950">{c.title}</div>
                    <div className="font-mono text-[11px] text-zinc-500">{c.category}</div>
                  </div>
                  <DifficultyBadge difficulty={c.difficulty} />
                </Link>
              ))
            )}
          </div>
        </Card>

        <div className="space-y-6">
          <Card className="p-5">
            <h2 className="text-sm font-semibold text-zinc-950 flex items-center gap-2">
              <Award className="h-4 w-4 text-amber-600" />
              Verified Achievements
            </h2>
            <div className="mt-3 space-y-2 text-xs">
              {portfolio.achievements.length === 0 ? (
                <p className="text-zinc-500">No achievements unlocked yet.</p>
              ) : (
                portfolio.achievements.map((a) => {
                  const meta = getAchievementMeta(a.achievementId);
                  return (
                    <div
                      key={a.achievementId}
                      className="rounded border border-zinc-200 p-2.5 space-y-1"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <span className="font-semibold text-zinc-950">{meta.title}</span>
                        <span className="text-[11px] text-zinc-500 shrink-0">
                          {new Date(a.awardedAt).toLocaleDateString()}
                        </span>
                      </div>
                      <p className="text-[11px] text-zinc-600">{meta.description}</p>
                    </div>
                  );
                })
              )}
            </div>
          </Card>

          <Card className="p-5">
            <h2 className="text-sm font-semibold text-zinc-950 flex items-center gap-2">
              <Trophy className="h-4 w-4 text-blue-700" />
              Competitions ({portfolio.contests.length})
            </h2>
            <div className="mt-3 space-y-2 text-xs">
              {portfolio.contests.length === 0 ? (
                <p className="text-zinc-500">No competition registrations yet.</p>
              ) : (
                portfolio.contests.map((ct) => (
                  <div key={ct.slug} className="rounded border border-zinc-200 p-2.5 font-medium">
                    {ct.title}
                  </div>
                ))
              )}
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}
