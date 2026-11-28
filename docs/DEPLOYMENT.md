# CONSINZO Deployment & Local Setup Guide

## 1. Local Development (Zero Paid Services Required)

1. Install dependencies:
   ```bash
   pnpm install
   ```
2. Copy `.env.example` to `.env.local`:
   ```bash
   cp .env.example .env.local
   ```
3. Validate all EVM & NEAR challenges:
   ```bash
   pnpm validate:challenges
   ```
4. Run unit, validator, EVM/NEAR runner, routing, and security tests:
   ```bash
   ./node_modules/.bin/vitest run packages/scoring/src/index.test.ts packages/validators/src/index.test.ts runners/evm/src/evm-runner.test.ts runners/near/src/near-runner.test.ts
   (cd apps/web && ../../node_modules/.bin/vitest run src/lib/platform.test.ts src/lib/challenges-routing.test.ts)
   ```
5. Start the Next.js development server:
   ```bash
   pnpm dev
   ```

## 2. Supabase Free-Tier Setup (PostgreSQL, Auth & Private Asset Storage)

1. Create a free-tier project at [supabase.com](https://supabase.com).
2. Apply SQL migrations in order via the Supabase SQL Editor:
   - `supabase/migrations/0001_initial_schema.sql`
   - `supabase/migrations/0002_rls_policies.sql`
   - `supabase/migrations/0003_difficulty_tiers_contact_identity.sql`
   - `supabase/seed.sql`
3. Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and `CONSINZO_PRIVATE_BUCKET=consinzo-private` in `.env.local` (and in Vercel Environment Variables).
4. Upload hidden tests and reference solutions to the private Supabase Storage bucket (`public: false`) and sync challenge metadata to PostgreSQL:
   ```bash
   pnpm sync:supabase
   ```
   When Supabase is configured, `apps/web` loads `evaluation/hidden/` and `solution/` from the private `consinzo-private` bucket using `SUPABASE_SERVICE_ROLE_KEY` server-side, falling back to local disk only if absent.

## 3. Vercel Deployment (`Root Directory = apps/web`)

- `apps/web/vercel.json` configures `pnpm install`, `pnpm build`, and `.next` output for `apps/web`.
- In **Vercel Project Settings → General → Root Directory**:
  - Set `apps/web` and keep **"Include source files outside of the Root Directory in the Build Step"** enabled so monorepo `packages/*`, `runners/*`, and `content/challenges/*` are accessible.
- `apps/web/next.config.ts` sets `outputFileTracingRoot` and `outputFileTracingIncludes` so `content/challenges/**` is bundled into serverless functions.
- Set `CONSINZO_EXECUTION_TIMEOUT_MS=8000` on Vercel Hobby to stay inside the 10s serverless execution window.
- Set `NEXT_PUBLIC_APP_URL` to the public origin (for example `https://consinzo.example`).
  Canonical URLs, Open Graph images, JSON-LD, `sitemap.xml`, `robots.txt` and `/llms.txt`
  are all built from it.
- Set `CONSINZO_AUTH_SECRET` to a 32-byte random value. If it is missing in production the
  app uses a random per-process secret: sessions cannot be forged, but they will not survive
  restarts or span instances.

## 4. Sign-in methods

| Method | Needs | Flag |
|---|---|---|
| Email and password | nothing | always on |
| Wallet (Sign-In with Ethereum) | nothing | always on |
| Google | Supabase provider + OAuth client | `CONSINZO_AUTH_GOOGLE=true` |
| GitHub | Supabase provider + OAuth app | `CONSINZO_AUTH_GITHUB=true` |
| Email code | Supabase email (SMTP for volume) | `CONSINZO_AUTH_EMAIL_CODE=true` |
| Phone code | Supabase phone provider (for example Twilio) | `CONSINZO_AUTH_PHONE=true` |

1. In Supabase, open **Authentication → Providers** and enable the providers you want.
2. In **Authentication → URL Configuration**, add `<your-site>/auth/callback` to Redirect URLs.
3. Set the matching flags above. A method whose flag is off is not shown on the sign-in page.
4. For email codes, make sure the email template includes the `{{ .Token }}` code (and the
   link, if you also want link sign-in).

Wallet accounts under Supabase are auth users with a placeholder address on
`wallet.consinzo.invalid`; the session is minted server-side after the signature is
verified. Only the public wallet address is stored (`profiles.wallet_address`).

Without Supabase, email and phone codes work only outside production (`pnpm dev`), where
the code is shown on the page instead of being sent.

## 5. Public contact details

The Contact page, footer and security policy show an email address or social link only when
its variable is set: `NEXT_PUBLIC_CONTACT_EMAIL`, `NEXT_PUBLIC_SECURITY_EMAIL`,
`NEXT_PUBLIC_SOCIAL_X`, `NEXT_PUBLIC_SOCIAL_GITHUB`, `NEXT_PUBLIC_SOCIAL_DISCORD`,
`NEXT_PUBLIC_SOCIAL_TELEGRAM`, `NEXT_PUBLIC_SOCIAL_FARCASTER`, `NEXT_PUBLIC_SOCIAL_LINKEDIN`.
Contact form messages are stored in `contact_messages` (Supabase) or the local store.

