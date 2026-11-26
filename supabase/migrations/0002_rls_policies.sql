-- Migration 0002: Row Level Security (RLS) Policies
-- Enforce zero-trust boundaries across all user-accessible tables.
-- Hidden test results, admin logs, and score mutations are restricted to server-side service role.

-- Helper function to check whether current auth user holds a specific admin role
CREATE OR REPLACE FUNCTION public.has_role(target_roles TEXT[])
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid()
      AND r.name = ANY(target_roles)
  );
$$;

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ecosystems ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.languages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.toolchains ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ecosystem_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_references ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.execution_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.execution_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.execution_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_findings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contest_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contest_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contest_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_paths ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_path_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skill_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contributor_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- PROFILES: Public read; users can only update safe profile fields (scores protected by column trigger/policy)
CREATE POLICY "profiles_public_read" ON public.profiles FOR SELECT USING (TRUE);
CREATE POLICY "profiles_owner_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_owner_update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND total_points = (SELECT p.total_points FROM public.profiles p WHERE p.id = auth.uid())
    AND challenges_completed = (SELECT p.challenges_completed FROM public.profiles p WHERE p.id = auth.uid())
    AND security_missions_completed = (SELECT p.security_missions_completed FROM public.profiles p WHERE p.id = auth.uid())
  );

-- USER SETTINGS: Owner only
CREATE POLICY "user_settings_owner_all" ON public.user_settings
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ROLES & USER ROLES: Read own roles or admin
CREATE POLICY "roles_public_read" ON public.roles FOR SELECT USING (TRUE);
CREATE POLICY "user_roles_self_or_admin" ON public.user_roles
  FOR SELECT USING (auth.uid() = user_id OR public.has_role(ARRAY['super_admin', 'platform_admin']));

-- PUBLIC CATALOGUE METADATA
CREATE POLICY "ecosystems_read" ON public.ecosystems FOR SELECT USING (TRUE);
CREATE POLICY "languages_read" ON public.languages FOR SELECT USING (TRUE);
CREATE POLICY "toolchains_read" ON public.toolchains FOR SELECT USING (TRUE);
CREATE POLICY "ecosystem_features_read" ON public.ecosystem_features FOR SELECT USING (TRUE);
CREATE POLICY "categories_read" ON public.challenge_categories FOR SELECT USING (TRUE);

-- CHALLENGES: Only published challenges readable publicly; admins/managers can see drafts
CREATE POLICY "challenges_read_published" ON public.challenges
  FOR SELECT USING (
    publication_status = 'published'
    OR public.has_role(ARRAY['super_admin', 'platform_admin', 'challenge_manager', 'content_editor'])
  );

CREATE POLICY "challenge_versions_read_published" ON public.challenge_versions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.challenges c
      WHERE c.id = challenge_id
        AND (c.publication_status = 'published' OR public.has_role(ARRAY['super_admin', 'platform_admin', 'challenge_manager']))
    )
  );

CREATE POLICY "challenge_tags_read" ON public.challenge_tags FOR SELECT USING (TRUE);
CREATE POLICY "challenge_refs_read" ON public.challenge_references FOR SELECT USING (TRUE);

-- SNAPSHOTS: Private to owner
CREATE POLICY "snapshots_owner_all" ON public.challenge_snapshots
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- SUBMISSIONS & EXECUTION: Owner read-only; mutations performed by server-side evaluation service
CREATE POLICY "submissions_owner_read" ON public.submissions
  FOR SELECT USING (auth.uid() = user_id OR public.has_role(ARRAY['super_admin', 'platform_admin']));

CREATE POLICY "execution_jobs_owner_read" ON public.execution_jobs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.submissions s WHERE s.id = submission_id AND s.user_id = auth.uid())
  );

CREATE POLICY "execution_results_owner_read" ON public.execution_results
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.submissions s WHERE s.id = submission_id AND s.user_id = auth.uid())
  );

-- CRITICAL SECURITY POLICY: Users can ONLY read PUBLIC test_results, NEVER 'hidden' rows!
CREATE POLICY "test_results_owner_public_only" ON public.test_results
  FOR SELECT USING (
    suite = 'public'
    AND EXISTS (SELECT 1 FROM public.submissions s WHERE s.id = submission_id AND s.user_id = auth.uid())
  );

CREATE POLICY "execution_logs_owner_read" ON public.execution_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.submissions s WHERE s.id = submission_id AND s.user_id = auth.uid())
  );

CREATE POLICY "challenge_unlocks_owner_read" ON public.challenge_unlocks
  FOR SELECT USING (auth.uid() = user_id);

-- SECURITY ARENA
CREATE POLICY "security_missions_read" ON public.security_missions
  FOR SELECT USING (publication_status = 'published' OR public.has_role(ARRAY['super_admin', 'platform_admin', 'security_reviewer']));

CREATE POLICY "audit_reports_owner_or_reviewer" ON public.audit_reports
  FOR SELECT USING (auth.uid() = author_id OR public.has_role(ARRAY['super_admin', 'platform_admin', 'security_reviewer']));
CREATE POLICY "audit_reports_owner_insert" ON public.audit_reports
  FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "security_findings_owner_or_reviewer" ON public.security_findings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.audit_reports ar
      WHERE ar.id = audit_report_id
        AND (ar.author_id = auth.uid() OR public.has_role(ARRAY['super_admin', 'platform_admin', 'security_reviewer']))
    )
  );

-- COMPETITIONS
CREATE POLICY "contests_public_read" ON public.contests
  FOR SELECT USING (visibility = 'public' OR organizer_id = auth.uid() OR public.has_role(ARRAY['super_admin', 'platform_admin', 'competition_organizer']));
CREATE POLICY "contest_challenges_read" ON public.contest_challenges FOR SELECT USING (TRUE);
CREATE POLICY "contest_scores_read" ON public.contest_scores FOR SELECT USING (TRUE);
CREATE POLICY "contest_entries_owner_or_org" ON public.contest_entries
  FOR SELECT USING (auth.uid() = user_id OR public.has_role(ARRAY['super_admin', 'platform_admin', 'competition_organizer']));

-- LEARNING & BOOKMARKS
CREATE POLICY "knowledge_read" ON public.knowledge_entries FOR SELECT USING (TRUE);
CREATE POLICY "learning_paths_read" ON public.learning_paths FOR SELECT USING (TRUE);
CREATE POLICY "learning_path_items_read" ON public.learning_path_items FOR SELECT USING (TRUE);
CREATE POLICY "achievements_read" ON public.achievements FOR SELECT USING (TRUE);
CREATE POLICY "user_achievements_read" ON public.user_achievements FOR SELECT USING (TRUE);
CREATE POLICY "skill_progress_read" ON public.skill_progress FOR SELECT USING (TRUE);
CREATE POLICY "bookmarks_owner_all" ON public.bookmarks
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ADMIN TABLES: Strictly restricted
CREATE POLICY "admin_audit_logs_restricted" ON public.admin_audit_logs
  FOR SELECT USING (public.has_role(ARRAY['super_admin', 'platform_admin']));
CREATE POLICY "system_settings_restricted" ON public.system_settings
  FOR SELECT USING (public.has_role(ARRAY['super_admin', 'platform_admin']));
