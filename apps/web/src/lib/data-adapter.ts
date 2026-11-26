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

export async function getLeaderboardEntries() {
  const env = getServerEnv();
  const supabase = getSupabaseAdminClient();
  if (env.isSupabaseConfigured && supabase) {
    const { data } = await supabase
      .from("profiles")
      .select("username, display_name, total_points, challenges_completed, security_missions_completed")
      .order("total_points", { ascending: false })
      .order("challenges_completed", { ascending: false })
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
  return db.users
    .map((u) => ({
      username: u.username,
      displayName: u.displayName,
      totalPoints: u.totalPoints,
      challengesCompleted: u.challengesCompleted,
      securityMissionsCompleted: u.securityMissionsCompleted,
    }))
    .sort((a, b) => b.totalPoints - a.totalPoints || b.challengesCompleted - a.challengesCompleted)
    .slice(0, 50);
}

export async function listAuditReportsForActor(userId: string, isReviewer: boolean): Promise<StoredAuditReport[]> {
  const db = readDb();
  return isReviewer
    ? db.auditReports
    : db.auditReports.filter((r) => r.authorId === userId);
}

export async function createAuditReport(report: StoredAuditReport): Promise<void> {
  const db = readDb();
  db.auditReports.unshift(report);
  writeDb(db);
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
    const [{ count: userCount }, { count: subCount }] = await Promise.all([
      supabase.from("profiles").select("id", { count: "exact", head: true }),
      supabase.from("submissions").select("id", { count: "exact", head: true }),
    ]);
    const db = readDb();
    return {
      registeredUsers: userCount ?? 0,
      totalSubmissions: subCount ?? 0,
      pendingAuditReports: db.auditReports.filter((r) => r.status === "submitted").length,
      recentSubmissions: [],
      auditReports: db.auditReports,
      auditLogs: db.adminAuditLogs.slice(0, 30),
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
