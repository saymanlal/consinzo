-- CONSINZO Proprietary Database Schema
-- Migration 0001: Core Normalized Schema (Identity, Ecosystems, Challenges, Execution, Security, Competitions, Learning, Administration)

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- 1. IDENTITY
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL UNIQUE CHECK (username ~ '^[a-zA-Z0-9_-]{3,32}$'),
  display_name TEXT NOT NULL,
  bio TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  github_url TEXT,
  website_url TEXT,
  total_points INTEGER NOT NULL DEFAULT 0 CHECK (total_points >= 0),
  challenges_completed INTEGER NOT NULL DEFAULT 0 CHECK (challenges_completed >= 0),
  security_missions_completed INTEGER NOT NULL DEFAULT 0 CHECK (security_missions_completed >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE CHECK (
    name IN (
      'developer',
      'content_editor',
      'competition_organizer',
      'security_reviewer',
      'ecosystem_manager',
      'challenge_manager',
      'platform_admin',
      'super_admin'
    )
  ),
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  granted_by UUID REFERENCES public.profiles(id),
  granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS public.user_settings (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  editor_theme TEXT NOT NULL DEFAULT 'consinzo-dark',
  editor_font_size INTEGER NOT NULL DEFAULT 14 CHECK (editor_font_size BETWEEN 11 AND 24),
  preferred_execution_mode TEXT NOT NULL DEFAULT 'local-cli',
  email_notifications BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- 2. ECOSYSTEMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.ecosystems (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  short_name TEXT NOT NULL,
  adapter_id TEXT NOT NULL UNIQUE,
  support_level SMALLINT NOT NULL DEFAULT 0 CHECK (support_level BETWEEN 0 AND 5),
  architecture_notes TEXT NOT NULL,
  official_docs_url TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.languages (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  monaco_language_id TEXT NOT NULL,
  ecosystem_id TEXT NOT NULL REFERENCES public.ecosystems(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.toolchains (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ecosystem_id TEXT NOT NULL REFERENCES public.ecosystems(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  pinned_version TEXT NOT NULL,
  cli_command TEXT,
  verified_at DATE NOT NULL,
  UNIQUE (ecosystem_id, name)
);

CREATE TABLE IF NOT EXISTS public.ecosystem_features (
  ecosystem_id TEXT PRIMARY KEY REFERENCES public.ecosystems(id) ON DELETE CASCADE,
  editor_syntax BOOLEAN NOT NULL DEFAULT FALSE,
  browser_compile BOOLEAN NOT NULL DEFAULT FALSE,
  browser_execute BOOLEAN NOT NULL DEFAULT FALSE,
  local_cli_compile BOOLEAN NOT NULL DEFAULT FALSE,
  local_cli_test BOOLEAN NOT NULL DEFAULT FALSE,
  remote_hidden_eval BOOLEAN NOT NULL DEFAULT FALSE,
  competition_isolated BOOLEAN NOT NULL DEFAULT FALSE
);

-- =============================================================================
-- 3. CHALLENGES
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.challenge_categories (
  id TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS public.challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  ecosystem_id TEXT NOT NULL REFERENCES public.ecosystems(id),
  language_id TEXT NOT NULL REFERENCES public.languages(id),
  category_id TEXT NOT NULL REFERENCES public.challenge_categories(id),
  difficulty TEXT NOT NULL CHECK (difficulty IN ('beginner', 'intermediate', 'advanced', 'expert')),
  publication_status TEXT NOT NULL DEFAULT 'draft' CHECK (publication_status IN ('draft', 'in_review', 'published', 'archived')),
  is_security_mission BOOLEAN NOT NULL DEFAULT FALSE,
  max_points INTEGER NOT NULL DEFAULT 100,
  maintainer_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.challenge_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  manifest_json JSONB NOT NULL,
  readme_markdown TEXT NOT NULL,
  starter_storage_path TEXT NOT NULL,
  hidden_eval_storage_path TEXT,
  solution_storage_path TEXT,
  is_immutable BOOLEAN NOT NULL DEFAULT FALSE,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (challenge_id, version)
);

CREATE TABLE IF NOT EXISTS public.challenge_tags (
  challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  PRIMARY KEY (challenge_id, tag)
);

CREATE TABLE IF NOT EXISTS public.challenge_references (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  source TEXT NOT NULL,
  version TEXT NOT NULL,
  verified_at DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS public.challenge_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_version_id UUID NOT NULL REFERENCES public.challenge_versions(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES public.profiles(id),
  decision TEXT NOT NULL CHECK (decision IN ('approved', 'changes_requested', 'rejected')),
  notes TEXT NOT NULL,
  reviewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.challenge_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  storage_object_key TEXT,
  inline_files_json JSONB,
  byte_size INTEGER NOT NULL CHECK (byte_size <= 262144),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, challenge_id)
);

-- =============================================================================
-- 4. EXECUTION & SUBMISSIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  challenge_version_id UUID REFERENCES public.challenge_versions(id),
  execution_mode TEXT NOT NULL CHECK (execution_mode IN ('browser-worker', 'local-cli', 'remote-actions')),
  snapshot_storage_key TEXT,
  status TEXT NOT NULL DEFAULT 'queued',
  score NUMERIC(6,2) NOT NULL DEFAULT 0 CHECK (score >= 0),
  passed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.execution_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id UUID NOT NULL UNIQUE REFERENCES public.submissions(id) ON DELETE CASCADE,
  runner_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  timeout_ms INTEGER NOT NULL DEFAULT 15000,
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.execution_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id UUID NOT NULL UNIQUE REFERENCES public.submissions(id) ON DELETE CASCADE,
  compiled BOOLEAN NOT NULL,
  compiler_version TEXT NOT NULL,
  duration_ms INTEGER NOT NULL,
  average_gas_used INTEGER,
  scoring_breakdown JSONB NOT NULL,
  hidden_evaluated BOOLEAN NOT NULL DEFAULT FALSE,
  hidden_passed_count INTEGER NOT NULL DEFAULT 0,
  hidden_total_count INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.test_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id UUID NOT NULL REFERENCES public.submissions(id) ON DELETE CASCADE,
  suite TEXT NOT NULL CHECK (suite IN ('public', 'hidden')),
  test_name TEXT NOT NULL,
  contract_name TEXT NOT NULL,
  passed BOOLEAN NOT NULL,
  gas_used INTEGER,
  duration_ms INTEGER NOT NULL,
  reason TEXT
);

CREATE TABLE IF NOT EXISTS public.execution_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id UUID NOT NULL UNIQUE REFERENCES public.submissions(id) ON DELETE CASCADE,
  sanitized_logs JSONB NOT NULL DEFAULT '[]'::jsonb,
  truncated BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.challenge_unlocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  solution_unlocked BOOLEAN NOT NULL DEFAULT FALSE,
  unlocked_reason TEXT,
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, challenge_id)
);

-- =============================================================================
-- 5. SECURITY ARENA
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.security_missions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  challenge_id UUID REFERENCES public.challenges(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  mission_type TEXT NOT NULL CHECK (mission_type IN ('exploit', 'patch', 'audit', 'ctf', 'incident_response')),
  vulnerability_class TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('critical', 'high', 'medium', 'low')),
  requires_human_review BOOLEAN NOT NULL DEFAULT FALSE,
  publication_status TEXT NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.audit_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id UUID NOT NULL REFERENCES public.security_missions(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('draft', 'submitted', 'under_review', 'accepted', 'needs_revision')),
  reviewer_id UUID REFERENCES public.profiles(id),
  reviewer_feedback TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.security_findings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_report_id UUID NOT NULL REFERENCES public.audit_reports(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('critical', 'high', 'medium', 'low', 'informational')),
  affected_component TEXT NOT NULL,
  root_cause TEXT NOT NULL,
  attack_scenario TEXT NOT NULL,
  impact TEXT NOT NULL,
  proof_of_concept TEXT NOT NULL,
  recommended_remediation TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS public.security_game_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id UUID NOT NULL REFERENCES public.security_missions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mode TEXT NOT NULL CHECK (mode IN ('red_team', 'blue_team')),
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMPTZ
);

-- =============================================================================
-- 6. COMPETITIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.contests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  contest_type TEXT NOT NULL CHECK (contest_type IN ('coding', 'security', 'university', 'sponsored')),
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public', 'private')),
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  organizer_id UUID NOT NULL REFERENCES public.profiles(id),
  rules_markdown TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.contest_challenges (
  contest_id UUID NOT NULL REFERENCES public.contests(id) ON DELETE CASCADE,
  challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  points_override INTEGER,
  display_order INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (contest_id, challenge_id)
);

CREATE TABLE IF NOT EXISTS public.teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contest_id UUID NOT NULL REFERENCES public.contests(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  captain_id UUID NOT NULL REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (contest_id, name)
);

CREATE TABLE IF NOT EXISTS public.team_members (
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (team_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.contest_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contest_id UUID NOT NULL REFERENCES public.contests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (contest_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.contest_scores (
  contest_id UUID NOT NULL REFERENCES public.contests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  total_score NUMERIC(8,2) NOT NULL DEFAULT 0,
  last_accepted_at TIMESTAMPTZ,
  PRIMARY KEY (contest_id, user_id)
);

-- =============================================================================
-- 7. LEARNING & PROGRESSION
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.knowledge_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  ecosystem_id TEXT NOT NULL REFERENCES public.ecosystems(id) ON DELETE CASCADE,
  entry_type TEXT NOT NULL CHECK (entry_type IN ('language', 'compiler', 'sdk', 'framework', 'standard', 'protocol', 'tool')),
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  body_markdown TEXT NOT NULL,
  source_url TEXT NOT NULL,
  applicable_version TEXT NOT NULL,
  last_verified_at DATE NOT NULL,
  review_status TEXT NOT NULL DEFAULT 'verified' CHECK (review_status IN ('draft', 'verified', 'needs_update'))
);

CREATE TABLE IF NOT EXISTS public.learning_paths (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  ecosystem_id TEXT REFERENCES public.ecosystems(id),
  description TEXT NOT NULL,
  difficulty TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS public.learning_path_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  learning_path_id UUID NOT NULL REFERENCES public.learning_paths(id) ON DELETE CASCADE,
  challenge_id UUID REFERENCES public.challenges(id) ON DELETE CASCADE,
  knowledge_entry_id UUID REFERENCES public.knowledge_entries(id) ON DELETE CASCADE,
  step_order INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS public.achievements (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  criteria_type TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS public.user_achievements (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  achievement_id TEXT NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
  submission_id UUID REFERENCES public.submissions(id),
  awarded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE IF NOT EXISTS public.skill_progress (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  ecosystem_id TEXT NOT NULL REFERENCES public.ecosystems(id) ON DELETE CASCADE,
  category_id TEXT NOT NULL REFERENCES public.challenge_categories(id) ON DELETE CASCADE,
  completed_count INTEGER NOT NULL DEFAULT 0,
  total_points INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, ecosystem_id, category_id)
);

CREATE TABLE IF NOT EXISTS public.bookmarks (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, challenge_id)
);

-- =============================================================================
-- 8. ADMINISTRATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES public.profiles(id),
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.content_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  reviewer_id UUID NOT NULL REFERENCES public.profiles(id),
  status TEXT NOT NULL,
  notes TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.contributor_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id),
  contribution_type TEXT NOT NULL,
  notes TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.system_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_by UUID REFERENCES public.profiles(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_challenges_ecosystem ON public.challenges(ecosystem_id, publication_status);
CREATE INDEX IF NOT EXISTS idx_submissions_user_created ON public.submissions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_submissions_challenge ON public.submissions(challenge_id, status);
CREATE INDEX IF NOT EXISTS idx_test_results_submission_suite ON public.test_results(submission_id, suite);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.admin_audit_logs(created_at DESC);
