-- 0003: six difficulty tiers, contact messages, and extra sign-in identities.
-- Safe to run more than once.

-- ── Difficulty: beginner < easy < normal < intermediate < hard < legend ──────────────
ALTER TABLE public.challenges DROP CONSTRAINT IF EXISTS challenges_difficulty_check;
UPDATE public.challenges SET difficulty = 'hard' WHERE difficulty = 'advanced';
UPDATE public.challenges SET difficulty = 'legend' WHERE difficulty = 'expert';
ALTER TABLE public.challenges
  ADD CONSTRAINT challenges_difficulty_check
  CHECK (difficulty IN ('beginner', 'easy', 'normal', 'intermediate', 'hard', 'legend'));

-- ── Contact form ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contact_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 2 AND 80),
  email TEXT NOT NULL CHECK (char_length(email) <= 160),
  topic TEXT NOT NULL CHECK (topic IN ('general', 'support', 'partnership', 'security', 'press')),
  message TEXT NOT NULL CHECK (char_length(message) BETWEEN 10 AND 4000),
  handled BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;
-- No anon/authenticated policies on purpose: rows are written and read only by the
-- server with the service-role key.

-- ── Sign-in identities on profiles ──────────────────────────────────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS wallet_address TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS auth_provider TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_wallet_address_key
  ON public.profiles (lower(wallet_address)) WHERE wallet_address IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_phone_key
  ON public.profiles (phone) WHERE phone IS NOT NULL;
