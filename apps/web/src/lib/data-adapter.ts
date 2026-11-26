import crypto from "node:crypto";
import type { ExecutionMode, RoleName, SubmissionStatus } from "@consinzo/shared";
import { ConsinzoError } from "@consinzo/shared";
import { getPublicChallengeBySlug } from "./challenges";
import { getServerEnv } from "./env";
import {
  readDb,
  writeDb,
  type StoredAuditLog,
  type StoredAuditReport,
  type StoredContest,
  type StoredSubmission,
  type StoredUnlock,
  type StoredUser,
} from "./store";
import { getSupabaseAdminClient } from "./supabase";

export interface PublicProfileView {
  id: string;
  email: string;
  username: string;
  displayName: string;
  bio: string;
  githubUrl: string;
  websiteUrl: string;
  roles: RoleName[];
  totalPoints: number;
  challengesCompleted: number;
  securityMissionsCompleted: number;
}

async function resolveSupabaseChallengeId(slug: string): Promise<string | null> {
  const supabase = getSupabaseAdminClient();
  if (!supabase) return null;

  const { data: existing } = await supabase
    .from("challenges")
    .select("id")
    .eq("slug", slug)
    .maybeSingle();

  if (existing?.id) return existing.id as string;

  // Auto-sync challenge row from manifest if database has not been seeded yet
  const challenge = getPublicChallengeBySlug(slug);
  if (!challenge) return null;
  const m = challenge.manifest;

  await supabase.from("languages").upsert(
    {
      id: `${m.ecosystem}-${m.language.toLowerCase()}`,
      name: m.language,
      monaco_language_id: m.language.toLowerCase() === "solidity" ? "sol" : m.language.toLowerCase(),
      ecosystem_id: m.ecosystem,
    },
    { onConflict: "id" }
  );

  const { data: inserted, error } = await supabase
    .from("challenges")
    .upsert(
      {
        slug: m.slug,
        title: m.title,
        description: m.description,
        ecosystem_id: m.ecosystem,
        language_id: `${m.ecosystem}-${m.language.toLowerCase()}`,
        category_id: m.category,
        difficulty: m.difficulty,
        publication_status: m.publication_status,
        is_security_mission: m.is_security_mission,
        max_points: m.scoring.max_points,
      },
      { onConflict: "slug" }
    )
    .select("id")
    .single();

  if (error || !inserted) return null;
  return inserted.id as string;
}

export async function getUserProfileById(userId: string): Promise<PublicProfileView | null> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", userId)
      .maybeSingle();
    if (!profile) return null;

    const { data: authData } = await supabase.auth.admin.getUserById(userId);
    const { data: roleRows } = await supabase
      .from("user_roles")
      .select("roles(name)")
      .eq("user_id", userId);

    const roles: RoleName[] =
      (roleRows ?? [])
        .map((r: { roles?: { name?: string } | Array<{ name?: string }> | null }) => {
          const rel = Array.isArray(r.roles) ? r.roles[0] : r.roles;
          return rel?.name as RoleName | undefined;
        })
        .filter((x): x is RoleName => Boolean(x)) || [];

    return {
      id: profile.id,
      email: authData?.user?.email ?? "",
      username: profile.username,
      displayName: profile.display_name,
      bio: profile.bio ?? "",
      githubUrl: profile.github_url ?? "",
      websiteUrl: profile.website_url ?? "",
      roles: roles.length > 0 ? roles : ["developer"],
      totalPoints: profile.total_points ?? 0,
      challengesCompleted: profile.challenges_completed ?? 0,
      securityMissionsCompleted: profile.security_missions_completed ?? 0,
    };
  }

  const db = readDb();
  const u = db.users.find((x) => x.id === userId);
  if (!u) return null;
  return {
    id: u.id,
    email: u.email,
    username: u.username,
    displayName: u.displayName,
    bio: u.bio,
    githubUrl: u.githubUrl,
    websiteUrl: u.websiteUrl,
    roles: u.roles,
    totalPoints: u.totalPoints,
    challengesCompleted: u.challengesCompleted,
    securityMissionsCompleted: u.securityMissionsCompleted,
  };
}

export async function updateUserProfileSafe(
  userId: string,
  updates: { displayName?: string; bio?: string; githubUrl?: string; websiteUrl?: string }
): Promise<PublicProfileView | null> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const patch: Record<string, string> = { updated_at: new Date().toISOString() };
    if (updates.displayName !== undefined) patch.display_name = updates.displayName;
    if (updates.bio !== undefined) patch.bio = updates.bio;
    if (updates.githubUrl !== undefined) patch.github_url = updates.githubUrl;
    if (updates.websiteUrl !== undefined) patch.website_url = updates.websiteUrl;

    await supabase.from("profiles").update(patch).eq("id", userId);
    return getUserProfileById(userId);
  }

  const db = readDb();
  const user = db.users.find((u) => u.id === userId);
  if (!user) return null;
  if (updates.displayName !== undefined) user.displayName = updates.displayName;
  if (updates.bio !== undefined) user.bio = updates.bio;
  if (updates.githubUrl !== undefined) user.githubUrl = updates.githubUrl;
  if (updates.websiteUrl !== undefined) user.websiteUrl = updates.websiteUrl;
  writeDb(db);
  return getUserProfileById(userId);
}

export async function countRecentSubmissions(userId: string, sinceIso: string): Promise<number> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { count } = await supabase
      .from("submissions")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("created_at", sinceIso);
    return count ?? 0;
  }

  const db = readDb();
  const sinceMs = new Date(sinceIso).getTime();
  return db.submissions.filter(
    (s) => s.userId === userId && new Date(s.createdAt).getTime() >= sinceMs
  ).length;
}

export async function listUserSubmissions(
  userId: string,
  challengeSlug?: string
): Promise<StoredSubmission[]> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    let query = supabase
      .from("submissions")
      .select(
        "id, user_id, execution_mode, status, score, passed, created_at, challenges!inner(slug, max_points), execution_results(*), test_results(*), execution_logs(sanitized_logs)"
      )
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(50);

    if (challengeSlug) {
      query = query.eq("challenges.slug", challengeSlug);
    }

    const { data } = await query;
    return (data ?? []).map((row: Record<string, unknown>) => {
      const chal = (Array.isArray(row.challenges) ? row.challenges[0] : row.challenges) as
        | { slug?: string; max_points?: number }
        | undefined;
      const execRes = (
        Array.isArray(row.execution_results) ? row.execution_results[0] : row.execution_results
      ) as Record<string, unknown> | undefined;
      const logRec = (
        Array.isArray(row.execution_logs) ? row.execution_logs[0] : row.execution_logs
      ) as { sanitized_logs?: string[] } | undefined;
      const tests = (row.test_results as Array<Record<string, unknown>> | undefined) ?? [];

      return {
        id: String(row.id),
        userId: String(row.user_id),
        challengeSlug: chal?.slug ?? challengeSlug ?? "",
        executionMode: row.execution_mode as ExecutionMode,
        runnerName: "solc-ethereumjs-evm",
        compilerVersion: String(execRes?.compiler_version ?? "0.8.28"),
        status: row.status as SubmissionStatus,
        compiled: Boolean(execRes?.compiled ?? true),
        score: Number(row.score ?? 0),
        maxPoints: Number(chal?.max_points ?? 100),
        passed: Boolean(row.passed),
        durationMs: Number(execRes?.duration_ms ?? 0),
        averageGasUsed: execRes?.average_gas_used ? Number(execRes.average_gas_used) : undefined,
        scoringBreakdown: (execRes?.scoring_breakdown as Record<string, unknown>) ?? {},
        publicTests: tests
          .filter((t) => t.suite === "public")
          .map((t) => ({
            name: String(t.test_name),
            contract: String(t.contract_name),
            passed: Boolean(t.passed),
            gasUsed: t.gas_used ? Number(t.gas_used) : undefined,
            durationMs: Number(t.duration_ms ?? 0),
            reason: t.reason ? String(t.reason) : undefined,
          })),
        hiddenSummary: execRes
          ? {
              evaluated: Boolean(execRes.hidden_evaluated),
              total: Number(execRes.hidden_total_count ?? 0),
              passed: Number(execRes.hidden_passed_count ?? 0),
              failed:
                Number(execRes.hidden_total_count ?? 0) - Number(execRes.hidden_passed_count ?? 0),
            }
          : undefined,
        sanitizedLogs: logRec?.sanitized_logs ?? [],
        createdAt: String(row.created_at),
      };
    });
  }

  const db = readDb();
  let items = db.submissions.filter((s) => s.userId === userId);
  if (challengeSlug) {
    items = items.filter((s) => s.challengeSlug === challengeSlug);
  }
  return items.slice(0, 50);
}

export async function saveEvaluatedSubmission(
  submission: StoredSubmission,
  options: { isSecurityMission: boolean; unlockPolicy: string }
): Promise<void> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const challengeId = await resolveSupabaseChallengeId(submission.challengeSlug);
    if (!challengeId) {
      throw new ConsinzoError("CHALLENGE_SYNC_ERROR", "Failed to resolve challenge record.", 500);
    }

    await supabase.from("submissions").insert({
      id: submission.id,
      user_id: submission.userId,
      challenge_id: challengeId,
      execution_mode: submission.executionMode,
      status: submission.status,
      score: submission.score,
      passed: submission.passed,
      created_at: submission.createdAt,
      completed_at: submission.createdAt,
    });

    await supabase.from("execution_results").insert({
      submission_id: submission.id,
      compiled: submission.compiled,
      compiler_version: submission.compilerVersion,
      duration_ms: submission.durationMs,
      average_gas_used: submission.averageGasUsed ?? null,
      scoring_breakdown: submission.scoringBreakdown,
      hidden_evaluated: Boolean(submission.hiddenSummary?.evaluated),
      hidden_passed_count: submission.hiddenSummary?.passed ?? 0,
      hidden_total_count: submission.hiddenSummary?.total ?? 0,
    });

    if (submission.publicTests.length > 0) {
      await supabase.from("test_results").insert(
        submission.publicTests.map((t) => ({
          submission_id: submission.id,
          suite: "public",
          test_name: t.name,
          contract_name: t.contract,
          passed: t.passed,
          gas_used: t.gasUsed ?? null,
          duration_ms: t.durationMs,
          reason: t.reason ?? null,
        }))
      );
    }

    await supabase.from("execution_logs").insert({
      submission_id: submission.id,
      sanitized_logs: submission.sanitizedLogs,
      truncated: false,
    });

    // Update challenge_unlocks and profile aggregates server-side
    const { data: prevPassedSubs } = await supabase
      .from("submissions")
      .select("id, score, passed")
      .eq("user_id", submission.userId)
      .eq("challenge_id", challengeId)
      .neq("id", submission.id);

    const previouslyPassed = (prevPassedSubs ?? []).some((s) => s.passed);
    const previousBest = (prevPassedSubs ?? []).reduce(
      (max, s) => Math.max(max, Number(s.score ?? 0)),
      0
    );
    const totalAttempts = (prevPassedSubs?.length ?? 0) + 1;

    const shouldUnlock =
      submission.passed ||
      (options.unlockPolicy === "after_3_attempts" && totalAttempts >= 3);

    const { data: existingUnlock } = await supabase
      .from("challenge_unlocks")
      .select("solution_unlocked")
      .eq("user_id", submission.userId)
      .eq("challenge_id", challengeId)
      .maybeSingle();

    await supabase.from("challenge_unlocks").upsert(
      {
        user_id: submission.userId,
        challenge_id: challengeId,
        solution_unlocked: Boolean(existingUnlock?.solution_unlocked) || shouldUnlock,
        unlocked_reason: submission.passed ? "passed" : shouldUnlock ? "after_3_attempts" : null,
      },
      { onConflict: "user_id,challenge_id" }
    );

    const { data: profile } = await supabase
      .from("profiles")
      .select("total_points, challenges_completed, security_missions_completed")
      .eq("id", submission.userId)
      .maybeSingle();

    if (profile) {
      const nextPoints =
        submission.score > previousBest
          ? Math.round(Number(profile.total_points ?? 0) + (submission.score - previousBest))
          : Number(profile.total_points ?? 0);
      const nextCompleted =
        submission.passed && !previouslyPassed
          ? Number(profile.challenges_completed ?? 0) + 1
          : Number(profile.challenges_completed ?? 0);
      const nextSec =
        submission.passed && !previouslyPassed && options.isSecurityMission
          ? Number(profile.security_missions_completed ?? 0) + 1
          : Number(profile.security_missions_completed ?? 0);

      await supabase
        .from("profiles")
        .update({
          total_points: nextPoints,
          challenges_completed: nextCompleted,
          security_missions_completed: nextSec,
          updated_at: new Date().toISOString(),
        })
        .eq("id", submission.userId);
    }

    if (submission.passed) {
      await supabase.from("user_achievements").upsert(
        {
          user_id: submission.userId,
          achievement_id: "first-verified-pass",
          submission_id: submission.id,
        },
        { onConflict: "user_id,achievement_id" }
      );
      if (options.isSecurityMission) {
        await supabase.from("user_achievements").upsert(
          {
            user_id: submission.userId,
            achievement_id: "security-defender",
            submission_id: submission.id,
          },
          { onConflict: "user_id,achievement_id" }
        );
      }
      if (
        submission.challengeSlug === "near-counter-contract" ||
        submission.challengeSlug === "near-dao-voting"
      ) {
        const { data: passedNearRows } = await supabase
          .from("submissions")
          .select("challenges!inner(slug)")
          .eq("user_id", submission.userId)
          .eq("passed", true)
          .in("challenges.slug", ["near-counter-contract", "near-dao-voting"]);
        const nearSet = new Set(
          (passedNearRows ?? []).map((r: Record<string, unknown>) => {
            const ch = (Array.isArray(r.challenges) ? r.challenges[0] : r.challenges) as
              | { slug?: string }
              | undefined;
            return ch?.slug ?? "";
          })
        );
        if (nearSet.has("near-counter-contract") && nearSet.has("near-dao-voting")) {
          await supabase.from("user_achievements").upsert(
            {
              user_id: submission.userId,
              achievement_id: "near-ts-architect",
              submission_id: submission.id,
            },
            { onConflict: "user_id,achievement_id" }
          );
        }
      }
    }

    // Update active Supabase contest_scores if user is registered in an active contest containing this challenge
    const nowIso = submission.createdAt;
    const { data: userEntries } = await supabase
      .from("contest_entries")
      .select(
        "contest_id, contests(id, starts_at, ends_at, contest_challenges(challenge_id))"
      )
      .eq("user_id", submission.userId);

    for (const entry of userEntries ?? []) {
      const c = (Array.isArray(entry.contests) ? entry.contests[0] : entry.contests) as
        | {
            id?: string;
            starts_at?: string;
            ends_at?: string;
            contest_challenges?: Array<{ challenge_id?: string }>;
          }
        | undefined;
      if (!c?.id || !c.starts_at || !c.ends_at) continue;
      if (nowIso < String(c.starts_at) || nowIso > String(c.ends_at)) continue;

      const contestChallengeIds = (c.contest_challenges ?? [])
        .map((cc) => cc.challenge_id)
        .filter((id): id is string => Boolean(id));
      if (!contestChallengeIds.includes(challengeId)) continue;

      const { data: userContestSubs } = await supabase
        .from("submissions")
        .select("challenge_id, score")
        .eq("user_id", submission.userId)
        .in("challenge_id", contestChallengeIds);

      const bestByChallenge = new Map<string, number>();
      for (const s of userContestSubs ?? []) {
        const cid = String(s.challenge_id);
        bestByChallenge.set(cid, Math.max(bestByChallenge.get(cid) ?? 0, Number(s.score ?? 0)));
      }
      const totalScore = Array.from(bestByChallenge.values()).reduce((sum, v) => sum + v, 0);

      const { data: existingContestScore } = await supabase
        .from("contest_scores")
        .select("last_accepted_at")
        .eq("contest_id", c.id)
        .eq("user_id", submission.userId)
        .maybeSingle();

      await supabase.from("contest_scores").upsert(
        {
          contest_id: c.id,
          user_id: submission.userId,
          total_score: totalScore,
          last_accepted_at: submission.passed
            ? nowIso
            : (existingContestScore?.last_accepted_at ?? nowIso),
        },
        { onConflict: "contest_id,user_id" }
      );

      if (submission.score > 0) {
        await supabase.from("user_achievements").upsert(
          {
            user_id: submission.userId,
            achievement_id: "contest-competitor",
            submission_id: submission.id,
          },
          { onConflict: "user_id,achievement_id" }
        );
      }
    }
    return;
  }

  // Local file-backed fallback
  const db = readDb();
  db.submissions.unshift(submission);

  let unlock = db.unlocks.find(
    (u) => u.userId === submission.userId && u.challengeSlug === submission.challengeSlug
  );
  const previouslyPassed = Boolean(unlock?.passed);
  const previousBest = unlock?.bestScore ?? 0;

  if (!unlock) {
    unlock = {
      userId: submission.userId,
      challengeSlug: submission.challengeSlug,
      passed: submission.passed,
      attempts: 1,
      bestScore: submission.score,
      solutionUnlocked: submission.passed,
      unlockedAt: submission.passed ? submission.createdAt : undefined,
    };
    db.unlocks.push(unlock);
  } else {
    unlock.attempts += 1;
    if (submission.score > unlock.bestScore) {
      unlock.bestScore = submission.score;
    }
    if (submission.passed && !unlock.passed) {
      unlock.passed = true;
      unlock.solutionUnlocked = true;
      unlock.unlockedAt = submission.createdAt;
    }
    if (
      options.unlockPolicy === "after_3_attempts" &&
      unlock.attempts >= 3 &&
      !unlock.solutionUnlocked
    ) {
      unlock.solutionUnlocked = true;
      unlock.unlockedAt = submission.createdAt;
    }
  }

  const user = db.users.find((u) => u.id === submission.userId);
  if (user) {
    if (submission.score > previousBest) {
      user.totalPoints =
        Math.round((user.totalPoints + (submission.score - previousBest)) * 100) / 100;
    }
    if (submission.passed && !previouslyPassed) {
      user.challengesCompleted += 1;
      if (options.isSecurityMission) {
        user.securityMissionsCompleted += 1;
      }

      const award = (achievementId: string) => {
        if (
          !db.achievements.some(
            (a) => a.userId === user.id && a.achievementId === achievementId
          )
        ) {
          db.achievements.push({
            userId: user.id,
            achievementId,
            awardedAt: submission.createdAt,
          });
        }
      };

      award("first-verified-pass");
      if (options.isSecurityMission) {
        award("security-defender");
      }
      const passedSlugs = new Set(
        db.unlocks.filter((u) => u.userId === user.id && u.passed).map((u) => u.challengeSlug)
      );
      if (passedSlugs.has("erc20-token-vault") && passedSlugs.has("erc721-royalty-nft")) {
        award("evm-token-architect");
      }
      if (passedSlugs.has("constant-product-amm") && passedSlugs.has("erc4626-tokenized-vault")) {
        award("defi-protocol-builder");
      }
      if (passedSlugs.has("near-counter-contract") && passedSlugs.has("near-dao-voting")) {
        award("near-ts-architect");
      }
      if (user.securityMissionsCompleted >= 5) {
        award("security-arena-specialist");
      }
    }

    // Update active contest_scores if user is registered in an active contest containing this challenge
    const nowIso = submission.createdAt;
    for (const contest of db.contests) {
      if (
        contest.registeredUserIds.includes(user.id) &&
        contest.challengeSlugs.includes(submission.challengeSlug) &&
        nowIso >= contest.startsAt &&
        nowIso <= contest.endsAt
      ) {
        const bestPerChallenge = contest.challengeSlugs.reduce((sum, cSlug) => {
          const best = db.submissions
            .filter((s) => s.userId === user.id && s.challengeSlug === cSlug)
            .reduce((mx, s) => Math.max(mx, s.score), 0);
          return sum + best;
        }, 0);

        const existingScore = db.contestScores.find(
          (cs) => cs.contestSlug === contest.slug && cs.userId === user.id
        );
        if (existingScore) {
          existingScore.totalScore = bestPerChallenge;
          if (submission.passed) existingScore.lastAcceptedAt = nowIso;
        } else {
          db.contestScores.push({
            contestSlug: contest.slug,
            userId: user.id,
            totalScore: bestPerChallenge,
            lastAcceptedAt: nowIso,
          });
        }
        if (
          submission.score > 0 &&
          !db.achievements.some(
            (a) => a.userId === user.id && a.achievementId === "contest-competitor"
          )
        ) {
          db.achievements.push({
            userId: user.id,
            achievementId: "contest-competitor",
            awardedAt: nowIso,
          });
        }
      }
    }
  }

  writeDb(db);
}

export async function isSolutionUnlockedForUser(
  userId: string,
  challengeSlug: string
): Promise<boolean> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const challengeId = await resolveSupabaseChallengeId(challengeSlug);
    if (!challengeId) return false;
    const { data } = await supabase
      .from("challenge_unlocks")
      .select("solution_unlocked")
      .eq("user_id", userId)
      .eq("challenge_id", challengeId)
      .maybeSingle();
    return Boolean(data?.solution_unlocked);
  }

  const db = readDb();
  const unlock = db.unlocks.find(
    (u) => u.userId === userId && u.challengeSlug === challengeSlug
  );
  return Boolean(unlock?.solutionUnlocked);
}

export async function getUserDashboardState(userId: string): Promise<{
  unlocks: StoredUnlock[];
  achievements: Array<{ achievementId: string; awardedAt: string }>;
  bookmarks: string[];
}> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const [{ data: unlockRows }, { data: achRows }, { data: bmRows }] = await Promise.all([
      supabase
        .from("challenge_unlocks")
        .select("solution_unlocked, unlocked_at, challenges(slug)")
        .eq("user_id", userId),
      supabase
        .from("user_achievements")
        .select("achievement_id, awarded_at")
        .eq("user_id", userId),
      supabase.from("bookmarks").select("challenges(slug)").eq("user_id", userId),
    ]);

    return {
      unlocks: (unlockRows ?? []).map((r: Record<string, unknown>) => {
        const chal = (Array.isArray(r.challenges) ? r.challenges[0] : r.challenges) as
          | { slug?: string }
          | undefined;
        return {
          userId,
          challengeSlug: chal?.slug ?? "",
          passed: Boolean(r.solution_unlocked),
          attempts: 1,
          bestScore: 0,
          solutionUnlocked: Boolean(r.solution_unlocked),
          unlockedAt: r.unlocked_at ? String(r.unlocked_at) : undefined,
        };
      }),
      achievements: (achRows ?? []).map((a) => ({
        achievementId: String(a.achievement_id),
        awardedAt: String(a.awarded_at),
      })),
      bookmarks: (bmRows ?? [])
        .map((b: Record<string, unknown>) => {
          const chal = (Array.isArray(b.challenges) ? b.challenges[0] : b.challenges) as
            | { slug?: string }
            | undefined;
          return chal?.slug ?? "";
        })
        .filter(Boolean),
    };
  }

  const db = readDb();
  return {
    unlocks: db.unlocks.filter((u) => u.userId === userId),
    achievements: db.achievements
      .filter((a) => a.userId === userId)
      .map((a) => ({ achievementId: a.achievementId, awardedAt: a.awardedAt })),
    bookmarks: db.bookmarks.filter((b) => b.userId === userId).map((b) => b.challengeSlug),
  };
}

export async function toggleBookmarkForUser(
  userId: string,
  challengeSlug: string
): Promise<boolean> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const challengeId = await resolveSupabaseChallengeId(challengeSlug);
    if (!challengeId) {
      throw new ConsinzoError("NOT_FOUND", "Challenge not found.", 404);
    }
    const { data: existing } = await supabase
      .from("bookmarks")
      .select("challenge_id")
      .eq("user_id", userId)
      .eq("challenge_id", challengeId)
      .maybeSingle();

    if (existing) {
      await supabase
        .from("bookmarks")
        .delete()
        .eq("user_id", userId)
        .eq("challenge_id", challengeId);
      return false;
    }
    await supabase.from("bookmarks").insert({ user_id: userId, challenge_id: challengeId });
    return true;
  }

  const db = readDb();
  const existingIdx = db.bookmarks.findIndex(
    (b) => b.userId === userId && b.challengeSlug === challengeSlug
  );
  if (existingIdx >= 0) {
    db.bookmarks.splice(existingIdx, 1);
    writeDb(db);
    return false;
  }
  db.bookmarks.push({ userId, challengeSlug, createdAt: new Date().toISOString() });
  writeDb(db);
  return true;
}

export type LeaderboardCategory = "overall" | "security" | "coding" | "weekly" | "monthly";

export async function getLeaderboardEntries(category: LeaderboardCategory = "overall") {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const orderCol =
      category === "security"
        ? "security_missions_completed"
        : category === "coding"
          ? "challenges_completed"
          : "total_points";

    const { data } = await supabase
      .from("profiles")
      .select("username, display_name, total_points, challenges_completed, security_missions_completed")
      .order(orderCol, { ascending: false })
      .order("total_points", { ascending: false })
      .limit(50);

    return (data ?? []).map((u) => ({
      username: u.username,
      displayName: u.display_name,
      totalPoints: u.total_points,
      challengesCompleted: u.challenges_completed,
      securityMissionsCompleted: u.security_missions_completed,
    }));
  }

  const db = readDb();
  const cutoffMs =
    category === "weekly"
      ? Date.now() - 7 * 24 * 60 * 60 * 1000
      : category === "monthly"
        ? Date.now() - 30 * 24 * 60 * 60 * 1000
        : 0;

  return db.users
    .map((u) => {
      if (cutoffMs > 0) {
        const windowSubs = db.submissions.filter(
          (s) => s.userId === u.id && s.passed && new Date(s.createdAt).getTime() >= cutoffMs
        );
        const bestBySlug = new Map<string, number>();
        for (const s of windowSubs) {
          bestBySlug.set(s.challengeSlug, Math.max(bestBySlug.get(s.challengeSlug) ?? 0, s.score));
        }
        const windowPoints = Array.from(bestBySlug.values()).reduce((a, b) => a + b, 0);
        return {
          username: u.username,
          displayName: u.displayName,
          totalPoints: windowPoints,
          challengesCompleted: bestBySlug.size,
          securityMissionsCompleted: u.securityMissionsCompleted,
        };
      }
      return {
        username: u.username,
        displayName: u.displayName,
        totalPoints: u.totalPoints,
        challengesCompleted: u.challengesCompleted,
        securityMissionsCompleted: u.securityMissionsCompleted,
      };
    })
    .sort((a, b) => {
      if (category === "security") {
        return (
          b.securityMissionsCompleted - a.securityMissionsCompleted ||
          b.totalPoints - a.totalPoints
        );
      }
      if (category === "coding") {
        return b.challengesCompleted - a.challengesCompleted || b.totalPoints - a.totalPoints;
      }
      return b.totalPoints - a.totalPoints || b.challengesCompleted - a.challengesCompleted;
    })
    .slice(0, 50);
}

export interface PublicDeveloperPortfolio {
  username: string;
  displayName: string;
  bio: string;
  githubUrl: string;
  websiteUrl: string;
  totalPoints: number;
  challengesCompleted: number;
  securityMissionsCompleted: number;
  joinedAt: string;
  completedChallenges: Array<{ slug: string; title: string; difficulty: string; category: string }>;
  achievements: Array<{ achievementId: string; awardedAt: string }>;
  contests: Array<{ slug: string; title: string }>;
}

export async function getPublicDeveloperPortfolio(
  username: string
): Promise<PublicDeveloperPortfolio | null> {
  const norm = username.trim().toLowerCase();
  if (!/^[a-z0-9_-]{3,32}$/.test(norm)) return null;

  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("*")
      .eq("username", norm)
      .maybeSingle();
    if (!profile) return null;

    const [{ data: unlockRows }, { data: achRows }, { data: entryRows }] = await Promise.all([
      supabase
        .from("challenge_unlocks")
        .select("solution_unlocked, challenges(slug, title, difficulty, category_id)")
        .eq("user_id", profile.id)
        .eq("solution_unlocked", true),
      supabase
        .from("user_achievements")
        .select("achievement_id, awarded_at")
        .eq("user_id", profile.id),
      supabase
        .from("contest_entries")
        .select("contests(slug, title)")
        .eq("user_id", profile.id),
    ]);

    return {
      username: profile.username,
      displayName: profile.display_name,
      bio: profile.bio ?? "",
      githubUrl: profile.github_url ?? "",
      websiteUrl: profile.website_url ?? "",
      totalPoints: profile.total_points ?? 0,
      challengesCompleted: profile.challenges_completed ?? 0,
      securityMissionsCompleted: profile.security_missions_completed ?? 0,
      joinedAt: profile.created_at,
      completedChallenges: (unlockRows ?? []).map((r: Record<string, unknown>) => {
        const ch = (Array.isArray(r.challenges) ? r.challenges[0] : r.challenges) as
          | { slug?: string; title?: string; difficulty?: string; category_id?: string }
          | undefined;
        return {
          slug: ch?.slug ?? "",
          title: ch?.title ?? "",
          difficulty: ch?.difficulty ?? "",
          category: ch?.category_id ?? "",
        };
      }),
      achievements: (achRows ?? []).map((a) => ({
        achievementId: String(a.achievement_id),
        awardedAt: String(a.awarded_at),
      })),
      contests: (entryRows ?? []).map((e: Record<string, unknown>) => {
        const ct = (Array.isArray(e.contests) ? e.contests[0] : e.contests) as
          | { slug?: string; title?: string }
          | undefined;
        return { slug: ct?.slug ?? "", title: ct?.title ?? "" };
      }),
    };
  }

  const db = readDb();
  const user = db.users.find((u) => u.username === norm);
  if (!user) return null;

  const passedSlugs = db.unlocks
    .filter((u) => u.userId === user.id && u.passed)
    .map((u) => u.challengeSlug);

  const completedChallenges = passedSlugs
    .map((slug) => getPublicChallengeBySlug(slug))
    .filter((c): c is NonNullable<typeof c> => Boolean(c))
    .map((c) => ({
      slug: c.manifest.slug,
      title: c.manifest.title,
      difficulty: c.manifest.difficulty,
      category: c.manifest.category,
    }));

  return {
    username: user.username,
    displayName: user.displayName,
    bio: user.bio,
    githubUrl: user.githubUrl,
    websiteUrl: user.websiteUrl,
    totalPoints: user.totalPoints,
    challengesCompleted: user.challengesCompleted,
    securityMissionsCompleted: user.securityMissionsCompleted,
    joinedAt: user.createdAt,
    completedChallenges,
    achievements: db.achievements
      .filter((a) => a.userId === user.id)
      .map((a) => ({ achievementId: a.achievementId, awardedAt: a.awardedAt })),
    contests: db.contests
      .filter((c) => c.registeredUserIds.includes(user.id))
      .map((c) => ({ slug: c.slug, title: c.title })),
  };
}

export async function createContestTeam(
  contestSlug: string,
  userId: string,
  name: string
) {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { data: contest } = await supabase
      .from("contests")
      .select("id")
      .eq("slug", contestSlug)
      .maybeSingle();
    if (!contest?.id) throw new ConsinzoError("NOT_FOUND", "Competition not found.", 404);

    const { data: team, error } = await supabase
      .from("teams")
      .insert({ contest_id: contest.id, name, captain_id: userId })
      .select("id, name, captain_id, created_at")
      .single();
    if (error || !team) {
      throw new ConsinzoError("TEAM_CREATE_FAILED", error?.message ?? "Team already exists.", 409);
    }
    await supabase.from("team_members").insert({ team_id: team.id, user_id: userId });
    await supabase
      .from("contest_entries")
      .upsert(
        { contest_id: contest.id, user_id: userId, team_id: team.id },
        { onConflict: "contest_id,user_id" }
      );
    return {
      id: team.id,
      contestSlug,
      name: team.name,
      captainId: team.captain_id,
      memberIds: [userId],
      createdAt: team.created_at,
    };
  }

  const db = readDb();
  const contest = db.contests.find((c) => c.slug === contestSlug);
  if (!contest) throw new ConsinzoError("NOT_FOUND", "Competition not found.", 404);
  if (db.teams.some((t) => t.contestSlug === contestSlug && t.name.toLowerCase() === name.toLowerCase())) {
    throw new ConsinzoError("TEAM_EXISTS", "A team with this name already exists in this contest.", 409);
  }
  const team = {
    id: crypto.randomUUID(),
    contestSlug,
    name,
    captainId: userId,
    memberIds: [userId],
    createdAt: new Date().toISOString(),
  };
  db.teams.push(team);
  if (!contest.registeredUserIds.includes(userId)) {
    contest.registeredUserIds.push(userId);
  }
  writeDb(db);
  return team;
}

export async function joinContestTeam(contestSlug: string, userId: string, teamId: string) {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { data: team } = await supabase
      .from("teams")
      .select("id, contest_id, name, captain_id, created_at")
      .eq("id", teamId)
      .maybeSingle();
    if (!team) throw new ConsinzoError("NOT_FOUND", "Team not found.", 404);

    await supabase
      .from("team_members")
      .upsert({ team_id: team.id, user_id: userId }, { onConflict: "team_id,user_id" });
    await supabase
      .from("contest_entries")
      .upsert(
        { contest_id: team.contest_id, user_id: userId, team_id: team.id },
        { onConflict: "contest_id,user_id" }
      );
    return {
      id: team.id,
      contestSlug,
      name: team.name,
      captainId: team.captain_id,
      memberIds: [userId],
      createdAt: team.created_at,
    };
  }

  const db = readDb();
  const contest = db.contests.find((c) => c.slug === contestSlug);
  if (!contest) throw new ConsinzoError("NOT_FOUND", "Competition not found.", 404);
  const team = db.teams.find((t) => t.contestSlug === contestSlug && t.id === teamId);
  if (!team) throw new ConsinzoError("NOT_FOUND", "Team not found.", 404);
  if (!team.memberIds.includes(userId)) team.memberIds.push(userId);
  if (!contest.registeredUserIds.includes(userId)) contest.registeredUserIds.push(userId);
  writeDb(db);
  return team;
}

export async function getContestDetailsAndStandings(contestSlug: string) {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { data: c } = await supabase
      .from("contests")
      .select("*, contest_challenges(challenges(slug)), contest_entries(user_id)")
      .eq("slug", contestSlug)
      .maybeSingle();
    if (!c) return null;

    const challengeRows = (c.contest_challenges as Array<Record<string, unknown>> | undefined) ?? [];
    const entryRows = (c.contest_entries as Array<{ user_id: string }> | undefined) ?? [];
    const challengeSlugs = challengeRows
      .map((cc) => {
        const ch = (Array.isArray(cc.challenges) ? cc.challenges[0] : cc.challenges) as
          | { slug?: string }
          | undefined;
        return ch?.slug ?? "";
      })
      .filter(Boolean);

    const contest: StoredContest = {
      slug: String(c.slug),
      title: String(c.title),
      description: String(c.description),
      contestType: c.contest_type as StoredContest["contestType"],
      visibility: c.visibility as StoredContest["visibility"],
      startsAt: String(c.starts_at),
      endsAt: String(c.ends_at),
      challengeSlugs,
      organizerId: String(c.organizer_id),
      registeredUserIds: entryRows.map((e) => e.user_id),
    };

    const [{ data: teamRows }, { data: scoreRows }] = await Promise.all([
      supabase
        .from("teams")
        .select("id, name, captain_id, created_at, team_members(user_id, profiles(username, display_name))")
        .eq("contest_id", c.id),
      supabase
        .from("contest_scores")
        .select("total_score, last_accepted_at, profiles(username, display_name)")
        .eq("contest_id", c.id)
        .order("total_score", { ascending: false })
        .order("last_accepted_at", { ascending: true }),
    ]);

    const teams = (teamRows ?? []).map((t: Record<string, unknown>) => {
      const tmRows =
        (t.team_members as Array<{
          user_id: string;
          profiles?: { username?: string; display_name?: string } | Array<{ username?: string; display_name?: string }>;
        }>) ?? [];
      return {
        id: String(t.id),
        contestSlug,
        name: String(t.name),
        captainId: String(t.captain_id),
        memberIds: tmRows.map((m) => String(m.user_id)),
        createdAt: String(t.created_at),
        members: tmRows.map((m) => {
          const prof = Array.isArray(m.profiles) ? m.profiles[0] : m.profiles;
          return {
            username: prof?.username ?? "developer",
            displayName: prof?.display_name ?? "Developer",
          };
        }),
      };
    });

    const standings = (scoreRows ?? []).map((cs: Record<string, unknown>) => {
      const prof = (Array.isArray(cs.profiles) ? cs.profiles[0] : cs.profiles) as
        | { username?: string; display_name?: string }
        | undefined;
      return {
        username: prof?.username ?? "developer",
        displayName: prof?.display_name ?? "Developer",
        totalScore: Number(cs.total_score ?? 0),
        lastAcceptedAt: String(cs.last_accepted_at ?? ""),
      };
    });

    return { contest, teams, standings };
  }

  const db = readDb();
  const contest = db.contests.find((c) => c.slug === contestSlug);
  if (!contest) return null;

  const teams = db.teams
    .filter((t) => t.contestSlug === contestSlug)
    .map((t) => ({
      ...t,
      members: t.memberIds.map((uid) => {
        const u = db.users.find((x) => x.id === uid);
        return { username: u?.username ?? "developer", displayName: u?.displayName ?? "Developer" };
      }),
    }));

  const standings = db.contestScores
    .filter((cs) => cs.contestSlug === contestSlug)
    .map((cs) => {
      const u = db.users.find((x) => x.id === cs.userId);
      return {
        username: u?.username ?? "developer",
        displayName: u?.displayName ?? "Developer",
        totalScore: cs.totalScore,
        lastAcceptedAt: cs.lastAcceptedAt,
      };
    })
    .sort((a, b) => b.totalScore - a.totalScore || a.lastAcceptedAt.localeCompare(b.lastAcceptedAt));

  return { contest, teams, standings };
}

async function resolveSupabaseSecurityMissionId(missionSlug: string): Promise<string | null> {
  const supabase = getSupabaseAdminClient();
  if (!supabase) return null;

  const { data: existing } = await supabase
    .from("security_missions")
    .select("id")
    .eq("slug", missionSlug)
    .maybeSingle();
  if (existing?.id) return existing.id as string;

  const challengeId = await resolveSupabaseChallengeId(missionSlug);
  const challenge = getPublicChallengeBySlug(missionSlug);
  if (!challenge) return null;

  const { data: created, error } = await supabase
    .from("security_missions")
    .upsert(
      {
        slug: challenge.manifest.slug,
        challenge_id: challengeId,
        title: challenge.manifest.title,
        mission_type: challenge.manifest.tags.includes("exploit") ? "exploit" : "patch",
        vulnerability_class: challenge.manifest.tags[0] ?? "smart-contract-security",
        severity:
          challenge.manifest.difficulty === "expert"
            ? "critical"
            : challenge.manifest.difficulty === "advanced"
              ? "high"
              : "medium",
        requires_human_review: true,
        publication_status: challenge.manifest.publication_status,
      },
      { onConflict: "slug" }
    )
    .select("id")
    .single();

  if (error || !created) return null;
  return created.id as string;
}

export async function listAuditReportsForActor(
  userId: string,
  isReviewer: boolean
): Promise<StoredAuditReport[]> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    let query = supabase
      .from("audit_reports")
      .select(
        "id, status, reviewer_feedback, submitted_at, author_id, security_missions(slug), security_findings(*), profiles!audit_reports_author_id_fkey(username)"
      )
      .order("submitted_at", { ascending: false })
      .limit(50);

    if (!isReviewer) {
      query = query.eq("author_id", userId);
    }

    const { data } = await query;
    return (data ?? []).map((row: Record<string, unknown>) => {
      const mission = (
        Array.isArray(row.security_missions) ? row.security_missions[0] : row.security_missions
      ) as { slug?: string } | undefined;
      const finding = (
        Array.isArray(row.security_findings) ? row.security_findings[0] : row.security_findings
      ) as Record<string, unknown> | undefined;
      const author = (Array.isArray(row.profiles) ? row.profiles[0] : row.profiles) as
        | { username?: string }
        | undefined;

      return {
        id: String(row.id),
        missionSlug: mission?.slug ?? "",
        authorId: String(row.author_id),
        authorUsername: author?.username ?? "researcher",
        title: String(finding?.title ?? "Security Finding"),
        severity: (finding?.severity as StoredAuditReport["severity"]) ?? "high",
        affectedComponent: String(finding?.affected_component ?? ""),
        rootCause: String(finding?.root_cause ?? ""),
        attackScenario: String(finding?.attack_scenario ?? ""),
        impact: String(finding?.impact ?? ""),
        proofOfConcept: String(finding?.proof_of_concept ?? ""),
        recommendedRemediation: String(finding?.recommended_remediation ?? ""),
        status: (row.status as StoredAuditReport["status"]) ?? "submitted",
        reviewerFeedback: row.reviewer_feedback ? String(row.reviewer_feedback) : undefined,
        createdAt: String(row.submitted_at),
      };
    });
  }

  const db = readDb();
  return isReviewer
    ? db.auditReports
    : db.auditReports.filter((r) => r.authorId === userId);
}

export async function createAuditReport(report: StoredAuditReport): Promise<void> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const missionId = await resolveSupabaseSecurityMissionId(report.missionSlug);
    if (!missionId) {
      throw new ConsinzoError("MISSION_NOT_FOUND", "Security mission not found.", 404);
    }

    const { error: repErr } = await supabase.from("audit_reports").insert({
      id: report.id,
      mission_id: missionId,
      author_id: report.authorId,
      status: report.status,
      submitted_at: report.createdAt,
    });
    if (repErr) {
      throw new ConsinzoError("DB_ERROR", repErr.message, 500);
    }

    await supabase.from("security_findings").insert({
      audit_report_id: report.id,
      title: report.title,
      severity: report.severity,
      affected_component: report.affectedComponent,
      root_cause: report.rootCause,
      attack_scenario: report.attackScenario,
      impact: report.impact,
      proof_of_concept: report.proofOfConcept,
      recommended_remediation: report.recommendedRemediation,
    });
    return;
  }

  const db = readDb();
  db.auditReports.unshift(report);
  writeDb(db);
}

export async function reviewAuditReport(input: {
  reportId: string;
  reviewerId: string;
  decision: "accepted" | "needs_revision";
  feedback: string;
}): Promise<StoredAuditReport | null> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { data: updated, error } = await supabase
      .from("audit_reports")
      .update({
        status: input.decision,
        reviewer_id: input.reviewerId,
        reviewer_feedback: input.feedback,
        reviewed_at: new Date().toISOString(),
      })
      .eq("id", input.reportId)
      .select("id")
      .maybeSingle();

    if (error || !updated) return null;

    await supabase.from("admin_audit_logs").insert({
      actor_id: input.reviewerId,
      action: `audit_report.${input.decision}`,
      target_type: "audit_report",
      target_id: input.reportId,
      metadata: { decision: input.decision },
    });

    const reports = await listAuditReportsForActor(input.reviewerId, true);
    return reports.find((r) => r.id === input.reportId) ?? null;
  }

  const db = readDb();
  const report = db.auditReports.find((r) => r.id === input.reportId);
  if (!report) return null;
  report.status = input.decision;
  report.reviewerFeedback = input.feedback;
  db.adminAuditLogs.unshift({
    id: crypto.randomUUID(),
    actorId: input.reviewerId,
    action: `audit_report.${input.decision}`,
    targetType: "audit_report",
    targetId: report.id,
    metadata: { missionSlug: report.missionSlug },
    createdAt: new Date().toISOString(),
  });
  writeDb(db);
  return report;
}

export async function listContestsWithCounts(): Promise<
  Array<StoredContest & { participantCount: number }>
> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { data } = await supabase
      .from("contests")
      .select("*, contest_challenges(challenges(slug)), contest_entries(user_id)")
      .order("starts_at", { ascending: false });

    if (data && data.length > 0) {
      return data.map((c: Record<string, unknown>) => {
        const challengeRows = (c.contest_challenges as Array<Record<string, unknown>> | undefined) ?? [];
        const entryRows = (c.contest_entries as Array<{ user_id: string }> | undefined) ?? [];
        const challengeSlugs = challengeRows
          .map((cc) => {
            const ch = (Array.isArray(cc.challenges) ? cc.challenges[0] : cc.challenges) as
              | { slug?: string }
              | undefined;
            return ch?.slug ?? "";
          })
          .filter(Boolean);
        return {
          slug: String(c.slug),
          title: String(c.title),
          description: String(c.description),
          contestType: c.contest_type as StoredContest["contestType"],
          visibility: c.visibility as StoredContest["visibility"],
          startsAt: String(c.starts_at),
          endsAt: String(c.ends_at),
          challengeSlugs,
          organizerId: String(c.organizer_id),
          registeredUserIds: entryRows.map((e) => e.user_id),
          participantCount: entryRows.length,
        };
      });
    }
  }

  const db = readDb();
  return db.contests.map((c) => ({
    ...c,
    participantCount: c.registeredUserIds.length,
  }));
}

export async function createContestRecord(contest: StoredContest): Promise<StoredContest> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { data: created, error } = await supabase
      .from("contests")
      .insert({
        slug: contest.slug,
        title: contest.title,
        description: contest.description,
        contest_type: contest.contestType,
        visibility: contest.visibility,
        starts_at: contest.startsAt,
        ends_at: contest.endsAt,
        organizer_id: contest.organizerId,
      })
      .select("id")
      .single();

    if (error || !created) {
      throw new ConsinzoError("CONTEST_CREATE_FAILED", error?.message ?? "Failed to create contest", 400);
    }

    for (let i = 0; i < contest.challengeSlugs.length; i++) {
      const chId = await resolveSupabaseChallengeId(contest.challengeSlugs[i]!);
      if (chId) {
        await supabase.from("contest_challenges").insert({
          contest_id: created.id,
          challenge_id: chId,
          display_order: i + 1,
        });
      }
    }
    return contest;
  }

  const db = readDb();
  db.contests.push(contest);
  writeDb(db);
  return contest;
}

export async function registerUserForContest(
  slug: string,
  userId: string
): Promise<{ registered: boolean; participantCount: number }> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { data: contest } = await supabase
      .from("contests")
      .select("id")
      .eq("slug", slug)
      .maybeSingle();

    if (contest?.id) {
      await supabase
        .from("contest_entries")
        .upsert({ contest_id: contest.id, user_id: userId }, { onConflict: "contest_id,user_id" });
      const { count } = await supabase
        .from("contest_entries")
        .select("id", { count: "exact", head: true })
        .eq("contest_id", contest.id);
      return { registered: true, participantCount: count ?? 1 };
    }
  }

  const db = readDb();
  const contest = db.contests.find((c) => c.slug === slug);
  if (!contest) {
    throw new ConsinzoError("NOT_FOUND", "Competition not found.", 404);
  }
  if (!contest.registeredUserIds.includes(userId)) {
    contest.registeredUserIds.push(userId);
    writeDb(db);
  }
  return { registered: true, participantCount: contest.registeredUserIds.length };
}

export async function getAdminStatsSnapshot(): Promise<{
  registeredUsers: number;
  totalSubmissions: number;
  pendingAuditReports: number;
  recentSubmissions: StoredSubmission[];
  auditReports: StoredAuditReport[];
  auditLogs: StoredAuditLog[];
}> {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const [{ count: userCount }, { count: subCount }, reports, { data: logRows }] =
      await Promise.all([
        supabase.from("profiles").select("id", { count: "exact", head: true }),
        supabase.from("submissions").select("id", { count: "exact", head: true }),
        listAuditReportsForActor("admin", true),
        supabase
          .from("admin_audit_logs")
          .select("*")
          .order("created_at", { ascending: false })
          .limit(30),
      ]);

    return {
      registeredUsers: userCount ?? 0,
      totalSubmissions: subCount ?? 0,
      pendingAuditReports: reports.filter((r) => r.status === "submitted").length,
      recentSubmissions: [],
      auditReports: reports,
      auditLogs: (logRows ?? []).map((l) => ({
        id: String(l.id),
        actorId: String(l.actor_id ?? ""),
        action: String(l.action),
        targetType: String(l.target_type),
        targetId: String(l.target_id),
        metadata: (l.metadata as Record<string, unknown>) ?? {},
        createdAt: String(l.created_at),
      })),
    };
  }

  const db = readDb();
  return {
    registeredUsers: db.users.length,
    totalSubmissions: db.submissions.length,
    pendingAuditReports: db.auditReports.filter((r) => r.status === "submitted").length,
    recentSubmissions: db.submissions.slice(0, 20),
    auditReports: db.auditReports,
    auditLogs: db.adminAuditLogs.slice(0, 30),
  };
}

export type { StoredContest, StoredUser };
