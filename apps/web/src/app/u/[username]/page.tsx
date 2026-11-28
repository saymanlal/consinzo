import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { CheckCircle2, ExternalLink, Github, Trophy } from "lucide-react";
import { Avatar } from "@/components/avatar";
import { BadgeShowcase } from "@/components/badge-showcase";
import { DifficultyBadge } from "@/components/difficulty-badge";
import { Container, DarkBand } from "@/components/marketing/blocks";
import { getAchievementMeta } from "@/lib/achievements";
import { getPublicDeveloperPortfolio } from "@/lib/data-adapter";
import { SITE } from "@/lib/site";

export const dynamic = "force-dynamic";

type Props = {
  params: Promise<{ username: string }>;
  searchParams: Promise<{ badge?: string }>;
};

export async function generateMetadata({ params, searchParams }: Props): Promise<Metadata> {
  const { username } = await params;
  const { badge } = await searchParams;
  const portfolio = await getPublicDeveloperPortfolio(username);
  if (!portfolio) return { title: "Developer not found", robots: { index: false } };

  const sharedBadge =
    badge && portfolio.achievements.some((a) => a.achievementId === badge)
      ? getAchievementMeta(badge)
      : null;
  const title = sharedBadge
    ? `${portfolio.displayName} earned “${sharedBadge.title}”`
    : `${portfolio.displayName} (@${portfolio.username})`;
  const description = sharedBadge
    ? `${sharedBadge.description} Verified on ${SITE.name}.`
    : `${portfolio.displayName} on ${SITE.name}: ${portfolio.challengesCompleted} challenges passed, ${portfolio.securityMissionsCompleted} security missions cleared, ${portfolio.totalPoints} verified points, ${portfolio.achievements.length} badges.`;
  const path = `/u/${portfolio.username}`;
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: { type: "profile", title, description, url: path, siteName: SITE.name },
    twitter: { card: "summary_large_image", title, description },
  };
}

export default async function PublicDeveloperProfilePage({ params, searchParams }: Props) {
  const { username } = await params;
  const { badge } = await searchParams;
  const portfolio = await getPublicDeveloperPortfolio(username);
  if (!portfolio) notFound();

  const stats = [
    { label: "Verified score", value: portfolio.totalPoints.toLocaleString("en-US") },
    { label: "Challenges passed", value: portfolio.challengesCompleted },
    { label: "Security missions", value: portfolio.securityMissionsCompleted },
    { label: "Badges", value: portfolio.achievements.length },
  ];

  return (
    <DarkBand>
      <Container className="py-10 sm:py-14">
        <header className="cz-card p-6 sm:p-8">
          <div className="flex flex-wrap items-start gap-5">
            <Avatar username={portfolio.username} displayName={portfolio.displayName} />
            <div className="min-w-0 flex-1">
              <h1 className="break-words text-2xl font-semibold tracking-tight text-white sm:text-3xl">
                {portfolio.displayName}
              </h1>
              <p className="mt-1 font-mono text-xs text-zinc-500">
                @{portfolio.username} · Joined{" "}
                <time dateTime={portfolio.joinedAt}>
                  {new Date(portfolio.joinedAt).toLocaleDateString("en-US", {
                    year: "numeric",
                    month: "short",
                    timeZone: "UTC",
                  })}
                </time>
              </p>
              {portfolio.bio && (
                <p className="mt-3 max-w-2xl text-sm leading-relaxed text-zinc-300">{portfolio.bio}</p>
              )}
              <div className="mt-4 flex flex-wrap gap-2">
                {portfolio.githubUrl && (
                  <a href={portfolio.githubUrl} target="_blank" rel="noopener noreferrer nofollow" className="cz-btn cz-btn-ghost px-3 py-1.5 text-xs">
                    <Github className="h-3.5 w-3.5" /> GitHub
                  </a>
                )}
                {portfolio.websiteUrl && (
                  <a href={portfolio.websiteUrl} target="_blank" rel="noopener noreferrer nofollow" className="cz-btn cz-btn-ghost px-3 py-1.5 text-xs">
                    <ExternalLink className="h-3.5 w-3.5" /> Website
                  </a>
                )}
              </div>
            </div>
          </div>
          <dl className="mt-7 grid grid-cols-2 gap-3 border-t border-white/10 pt-6 sm:grid-cols-4">
            {stats.map((s) => (
              <div key={s.label}>
                <dt className="text-xs text-zinc-500">{s.label}</dt>
                <dd className="mt-1 font-mono text-2xl font-semibold text-white">{s.value}</dd>
              </div>
            ))}
          </dl>
        </header>

        <div className="mt-10">
          <BadgeShowcase
            profile={{
              username: portfolio.username,
              displayName: portfolio.displayName,
              totalPoints: portfolio.totalPoints,
              challengesCompleted: portfolio.challengesCompleted,
              securityMissionsCompleted: portfolio.securityMissionsCompleted,
            }}
            earned={portfolio.achievements}
            highlightId={badge}
          />
        </div>

        <div className="mt-10 grid gap-6 lg:grid-cols-3">
          <section className="cz-card p-6 lg:col-span-2">
            <h2 className="flex items-center gap-2 text-sm font-semibold text-white">
              <CheckCircle2 className="h-4 w-4 text-emerald-400" />
              Verified completions ({portfolio.completedChallenges.length})
            </h2>
            <div className="mt-4 space-y-2">
              {portfolio.completedChallenges.length === 0 ? (
                <p className="text-sm text-zinc-500">No verified completions yet.</p>
              ) : (
                portfolio.completedChallenges.map((c) => (
                  <Link
                    key={c.slug}
                    href={`/challenges/${c.slug}`}
                    className="cz-focus flex items-center justify-between gap-3 rounded-xl border border-white/10 px-4 py-3 text-sm transition hover:border-white/25 hover:bg-white/[0.04]"
                  >
                    <span className="min-w-0">
                      <span className="block truncate font-medium text-white">{c.title}</span>
                      <span className="font-mono text-[11px] text-zinc-500">{c.category}</span>
                    </span>
                    <DifficultyBadge difficulty={c.difficulty} surface="dark" className="shrink-0" />
                  </Link>
                ))
              )}
            </div>
          </section>

          <section className="cz-card p-6">
            <h2 className="flex items-center gap-2 text-sm font-semibold text-white">
              <Trophy className="h-4 w-4 text-violet-300" />
              Competitions ({portfolio.contests.length})
            </h2>
            <div className="mt-4 space-y-2 text-sm">
              {portfolio.contests.length === 0 ? (
                <p className="text-zinc-500">No competition entries yet.</p>
              ) : (
                portfolio.contests.map((ct) => (
                  <div key={ct.slug} className="rounded-xl border border-white/10 px-4 py-3 font-medium text-zinc-200">
                    {ct.title}
                  </div>
                ))
              )}
            </div>
          </section>
        </div>
      </Container>
    </DarkBand>
  );
}
