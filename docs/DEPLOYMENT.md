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
3. Validate all 38 EVM & NEAR challenges:
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
   - `supabase/seed.sql`
3. Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and `CONSINZO_PRIVATE_BUCKET=consinzo-private` in `.env.local` (and in Vercel Environment Variables).
4. Upload hidden tests and reference solutions to the private Supabase Storage bucket (`public: false`) and sync challenge metadata to PostgreSQL:
   ```bash
   pnpm sync:supabase
   ```
   When Supabase is configured, `apps/web` loads `evaluation/hidden/` and `solution/` from the private `consinzo-private` bucket using `SUPABASE_SERVICE_ROLE_KEY` server-side, falling back to local disk only if absent.

## 3. Vercel Deployment (`Root Directory = apps/web`)

- [apps/web/vercel.json](file:///Users/shalabksr23/ALL%20PROJECT%20FOLDER/Consinzo/apps/web/vercel.json) configures `pnpm install`, `pnpm build`, and `.next` output for `apps/web`.
- In **Vercel Project Settings → General → Root Directory**:
  - Set `apps/web` and keep **"Include source files outside of the Root Directory in the Build Step"** enabled so monorepo `packages/*`, `runners/*`, and `content/challenges/*` are accessible.
- [apps/web/next.config.ts](file:///Users/shalabksr23/ALL%20PROJECT%20FOLDER/Consinzo/apps/web/next.config.ts) sets `outputFileTracingRoot` and `outputFileTracingIncludes` so `content/challenges/**` is bundled into serverless functions.
- Set `CONSINZO_EXECUTION_TIMEOUT_MS=8000` on Vercel Hobby to stay inside the 10s serverless execution window.
