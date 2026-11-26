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
3. Validate all 10 EVM challenges (starter compilation + reference solution vs public & hidden tests):
   ```bash
   pnpm validate:challenges
   ```
4. Run unit, validator, EVM runner, and security tests:
   ```bash
   ./node_modules/.bin/vitest run
   ```
5. Start the Next.js development server:
   ```bash
   pnpm dev
   ```
   Open `http://localhost:3000`.

## 2. Supabase Free-Tier Setup

1. Create a free-tier project at [supabase.com](https://supabase.com).
2. Apply SQL migrations in order via the Supabase SQL Editor or CLI:
   - `supabase/migrations/0001_initial_schema.sql`
   - `supabase/migrations/0002_rls_policies.sql`
   - `supabase/seed.sql`
3. Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` in `.env.local` (never expose `SUPABASE_SERVICE_ROLE_KEY` to client bundles).

## 3. Vercel / Cloudflare Pages Deployment

- **Vercel**: Import the private GitHub repository, set root directory to repository root (or configure `pnpm --filter @consinzo/web build`), and add environment variables in Vercel Project Settings.
- **Cloudflare Pages**: Use `@cloudflare/next-on-pages` with Node compatibility enabled for static + edge routes. Note: `solc` WASM compilation in serverless functions requires Node.js runtime (`nodejs`).

## 4. Troubleshooting

- **Foundry (`forge`) not installed**: CONSINZO automatically uses bundled `solc@0.8.28` + `@ethereumjs/evm` with Foundry-compatible `forge-std/Test.sol` & `Vm.sol` cheatcodes. Run `pnpm cli -- doctor` to inspect active toolchains.
- **Mode C Remote Evaluation**: Intentionally disabled (`CONSINZO_ENABLE_REMOTE_ACTIONS_EVAL=false`) until an isolated microVM runner is provisioned.
