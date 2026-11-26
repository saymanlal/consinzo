# CONSINZO Internal Engineering Guidelines

**PROPRIETARY — AUTHORIZED PERSONNEL ONLY**

This repository is private and proprietary. Do not share source code, hidden tests,
reference solutions, or internal schemas outside authorized CONSINZO engineering environments.

## Workspace Commands

- `pnpm install` — Install workspace dependencies
- `pnpm dev` — Start the Next.js web application (`apps/web`)
- `pnpm typecheck` — Run strict TypeScript checks across all packages
- `pnpm lint` — Lint all packages
- `pnpm test` — Run unit, security, validator, and runner test suites
- `pnpm validate:challenges` — Validate all `content/challenges/*` manifests and starter projects
- `pnpm verify:licenses` — Audit third-party dependency licenses
- `pnpm cli -- --help` — Run the CONSINZO local EVM runner CLI

## Authoring Rules

1. Never place hidden tests or solutions in `starter/` or `evaluation/public/`.
2. Never add open-source license headers to CONSINZO proprietary files.
3. Every challenge must compile and pass its reference solution against both public and
   hidden tests before its `publication_status` can be set to `published`.
4. Never fabricate ecosystem support levels in `@consinzo/ecosystem-registry`.
   Only elevate a support level after automated integration tests verify it.
