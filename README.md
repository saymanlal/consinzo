# CONSINZO — The Engineering Platform

**Build. Test. Break. Master.**

CONSINZO is a proprietary multi-ecosystem blockchain and smart-contract engineering platform
built on a zero-paid-infrastructure-first architecture.

## Monorepo Layout

- `apps/web` — Next.js App Router application (Public Portal, Codex Workspace, Security Arena, Protocol Lab, Ecosystem Hub, Competitions, Academy, Admin)
- `packages/shared` — Shared types, quota limits, error shapes, design tokens
- `packages/ecosystem-registry` — Validated 10-ecosystem capability & support-level registry (Levels 0–5)
- `packages/challenge-spec` — Versioned challenge manifest Zod schemas & loader
- `packages/validators` — Challenge package, security mission, and snapshot validators
- `packages/scoring` — Configurable weighted scoring engine (correctness, invariants, efficiency, quality)
- `packages/execution-sdk` — Execution mode interfaces (Mode A Browser, Mode B Local CLI, Mode C Remote)
- `packages/editor` — Monaco Editor configuration & Solidity/Move/Rust/Cairo language support
- `packages/ui` — Design system primitives (shadcn/ui-compatible Tailwind components)
- `runners/common` — Common runner interfaces, output sanitizers, and quota guards
- `runners/evm` — Real Solidity (`solc`) + EVM (`@ethereumjs/vm` & native `forge`) runner & CLI
- `runners/near` — NEAR TypeScript runner (type-check + in-process execution against an SDK shim)
- `content/` — Challenges, security missions, protocol labs, ecosystem references, learning paths
- `supabase/` — Versioned PostgreSQL migrations, RLS policies, and seed data
- `scripts/` — Challenge package validator, license inventory, and infrastructure checks
- `docs/` — Deployment guide, free-tier infrastructure cost register, and API reference

## Quick Start (Local Development)

1. Install dependencies: `pnpm install`
2. Copy environment template: `cp .env.example .env.local`
3. Validate all challenge packages: `pnpm validate:challenges` (or only some: `pnpm validate:challenges -- <slug> <slug>`)
4. Run all tests: `pnpm test`
5. Start the web app: `pnpm dev`

## What the web app provides

- **Challenge Codex** with six difficulty tiers (beginner, easy, normal, intermediate, hard,
  legend), filters for tier, ecosystem, language, category and type, and shareable filter URLs.
- **Guest mode**: run public tests without an account, with an hourly run budget and the
  entry tiers only. Limits live in `apps/web/src/lib/guest-limits.ts`.
- **Sign-in**: email and password, wallet (Sign-In with Ethereum), and, through Supabase
  Auth, Google, GitHub, email codes and SMS codes. People without a wallet can create one in
  the browser; the recovery phrase never reaches the server. See `docs/DEPLOYMENT.md`.
- **Profiles and badges**: public portfolio at `/u/<username>`, badge medallions, and a
  share dialog with caption drafts for X, LinkedIn, Farcaster, Reddit and other networks.
- **SEO/AEO**: per-page metadata and canonicals, JSON-LD, `sitemap.xml`, `robots.txt`,
  `/llms.txt`, and a brand kit under `apps/web/public/brand`.

## Authoring challenges

Every package under `content/challenges/<slug>/` must satisfy `pnpm validate:challenges`:
the manifest matches the schema, the starter compiles and **fails** at least one test, and
the reference solution passes every public and hidden test.
