# Pending tasks

Snapshot: 2026-11-28, branch `feat/web3-frontend-auth`. Everything listed under "Done" is
built, tested and in this branch. Everything under "Pending" is deliberately left for
afterwards.

## Done in this branch

- Brand: logo in the navbar/footer, favicons, PWA manifest, brand kit in `apps/web/public/brand`.
- Web3 design system and rebuilt Home, About, Contact, Docs, Legal, 404, Sign-in, Profile
  and public portfolio pages.
- Six difficulty tiers with catalogue filters, sort, paging and shareable filter URLs.
- Sign-in: email + password and wallet (Sign-In with Ethereum) work out of the box.
  Google, GitHub, email-code and phone-code sign-in are implemented behind flags.
- In-browser wallet creation with an encrypted on-device copy of the recovery phrase.
- Guest mode with run limits.
- Badge medallions and a share dialog with caption drafts for nine networks.
- Per-page SEO metadata, canonicals, JSON-LD, FAQ, `sitemap.xml`, `robots.txt`, `/llms.txt`.
- Security headers, rate limits on sign-in and run endpoints, no forgeable fallback secret.
- Challenge library: **181 verified challenges** (156 Solidity/EVM, 25 NEAR TypeScript;
  54 security missions). Tiers: 36 beginner, 36 easy, 38 normal, 38 intermediate, 28 hard,
  5 legend.

## Go-live checklist (needed for a real production deployment)

1. Vercel project: Root Directory `apps/web`, "include files outside the root directory" on.
2. Set `NEXT_PUBLIC_APP_URL` to the public origin. Canonicals, social images, JSON-LD,
   the sitemap and `/llms.txt` are built from it.
3. Set `CONSINZO_AUTH_SECRET` to a 32-byte random value.
4. Configure Supabase (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`,
   `SUPABASE_SERVICE_ROLE_KEY`), apply migrations `0001` to `0003` and the seed, then run
   `pnpm sync:supabase`. Without Supabase, accounts and submissions are kept in temporary
   storage on serverless hosts and will not persist.
5. Set `CONSINZO_EXECUTION_TIMEOUT_MS=8000` on Vercel Hobby.
6. Optional sign-in methods: enable the provider in Supabase, add
   `<site>/auth/callback` to its redirect URLs, then set `CONSINZO_AUTH_GOOGLE`,
   `CONSINZO_AUTH_GITHUB`, `CONSINZO_AUTH_EMAIL_CODE`, `CONSINZO_AUTH_PHONE` to `true`.
   Set these before building: the public pages list the enabled methods at build time.
7. Optional contact details: `NEXT_PUBLIC_CONTACT_EMAIL`, `NEXT_PUBLIC_SECURITY_EMAIL`,
   `NEXT_PUBLIC_SOCIAL_*`.

See `docs/DEPLOYMENT.md` for the detail behind each step.

## Pending

### Challenge library: 181 of the 300+ target

About 120 more verified challenges are still to be written. Remaining topics by theme:

| Theme | Remaining (approx.) |
|---|---|
| DeFi, advanced (money market, concentrated liquidity, perps, liquid staking, …) | 12 |
| Security missions, advanced and audit-depth (exploit chains) | 9 |
| Security missions, intermediate | 9 |
| Infrastructure (diamond tooling, RLP, interpreter, fraud proofs, …) | 9 |
| Cross-chain and integrations | 8 |
| Protocols and governance | 13 |
| Token standards | 7 |
| NEAR TypeScript, protocols and security | 15 |
| Legend tier across all themes (currently only 5) | priority |
| Remaining fundamentals, entry-level security, DeFi basics | balance |

Rule that stays in force: a challenge ships only if `pnpm validate:challenges -- <slug>`
passes (starter compiles and fails, reference passes all public and hidden tests).

### Other languages

Rust (Solana, CosmWasm), Move (Sui, Aptos), Cairo, Vyper and the rest have no runner, so
no challenges were written for them: they could not be compiled or checked. Each needs a
runner first.

### Verification still to do by hand

- Google, GitHub, email-code and phone-code sign-in, and wallet sign-in in Supabase mode,
  have not been exercised against a live Supabase project.
- Click through the create-wallet flow and the share dialog in a real browser once.

### Engineering follow-ups

- ESLint has no flat config, so `pnpm lint` fails; add one and run it in CI.
- Rate limits are per server instance; add an edge/WAF limit for hard guarantees.
- Wallet sign-in supports externally owned accounts; smart-contract wallets (EIP-1271)
  are not supported yet.
- No Content-Security-Policy header yet (needs care with the Monaco editor).
- Per-user linking of a second sign-in method (for example adding a wallet to an email
  account) is not built.
- Isolated remote evaluation (Mode C) is still disabled; user code runs in-process.
- Component and end-to-end browser tests.
