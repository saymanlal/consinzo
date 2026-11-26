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
- `content/` — Challenges, security missions, protocol labs, ecosystem references, learning paths
- `supabase/` — Versioned PostgreSQL migrations, RLS policies, and seed data
- `scripts/` — Challenge package validator, license inventory, and infrastructure checks
- `docs/` — Deployment guide, free-tier infrastructure cost register, and API reference

## Quick Start (Local Development)

1. Install dependencies: `pnpm install`
2. Copy environment template: `cp .env.example .env.local`
3. Validate all challenge packages: `pnpm validate:challenges`
4. Run all tests: `pnpm test`
5. Start the web app: `pnpm dev`
# consinzo
# consinzo
# consinzo
# consinzo
