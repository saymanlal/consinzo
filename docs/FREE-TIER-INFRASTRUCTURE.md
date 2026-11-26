# CONSINZO Free-Tier Infrastructure Cost Register

Last verified: 2026-11-27

CONSINZO is engineered around a **zero-paid-infrastructure-first** constraint. No paid cloud
service is mandatory for local development or initial public beta.

| Service | Purpose | Free Allowance (Verify Before Scale) | Current Usage | Known Limitations | Upgrade Trigger | Alternative Solution |
|---|---|---|---|---|---|---|
| **Vercel Hobby** | Next.js App Router hosting | 100 GB bandwidth / mo, serverless execution limits | $0 (dev local) | Serverless function max duration (10s–60s); commercial use requires Pro | Sustained public commercial traffic or >10s function duration | Cloudflare Pages (`@cloudflare/next-on-pages`) or self-hosted Node |
| **Supabase Free** | PostgreSQL, Auth, RLS, Storage | 500 MB DB, 1 GB file storage, 50K MAU, pauses after 7 days inactivity | $0 (migrations ready; local file store fallback) | 2 active free projects max; inactivity pause | >500 MB DB or >50K MAU or zero-pause SLA | Local PostgreSQL / Docker Postgres / Neon free tier |
| **GitHub Private Repo & Actions** | Source control, CI, challenge validation | 2,000 Actions minutes/mo on private repos (Free plan) | $0 | 2,000 min/mo shared across CI & evaluation | Exhausting 2,000 min/mo or needing microVM isolation | Local CLI (`pnpm cli -- test`) + self-hosted Firecracker runner |
| **Cloudflare Free** | DNS, TLS, static edge caching | Unmetered standard DDoS & DNS | $0 | Workers CPU time limits on free tier | Edge compute >10ms CPU time | Vercel built-in edge network |
| **Bundled `solc` + `@ethereumjs/evm` & NEAR TS VM** | Solidity EVM & NEAR TypeScript test runners | 100% local / in-process | $0 | Single-threaded JS / `node:vm` execution; does not enforce OS-level syscall isolation for hostile multi-tenant workloads | Untrusted multi-tenant remote competition execution | Dedicated Firecracker / gVisor ephemeral worker pool |
