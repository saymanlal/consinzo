# CONSINZO Security Policy

Copyright (c) 2026 CONSINZO. All Rights Reserved.

## Execution Threat Model

Every user-submitted code snapshot, test file, or exploit payload is treated as **hostile**.

### Core Invariants

1. **No Untrusted Execution in Next.js Server Request Handlers**:
   User-submitted Solidity or smart-contract code must never execute arbitrary OS commands
   or native binaries inside a production web request handler without process/VM isolation.
2. **Browser Mode (Mode A)**:
   Runs `solc` (WASM) and EthereumJS EVM inside an isolated Web Worker. Browser execution
   is **untrusted** for competition scoring or security verification.
3. **Local CLI Mode (Mode B)**:
   Runs on the developer's own machine via `@consinzo/runner-evm` (`forge` / `solc`).
   Results are for local iteration and diagnostics.
4. **Remote Evaluation (Mode C)**:
   Disabled by default unless an isolated runner environment is explicitly configured.
   GitHub Actions workflows must NEVER check out untrusted PR code in a context with
   repository secrets or private hidden test assets.
5. **Hidden Test & Solution Isolation**:
   `evaluation/hidden/` and `solution/` directories are excluded from public client payloads
   and protected behind server-side authorization checks and challenge unlock records.
6. **Row Level Security (RLS)**:
   All user-accessible Supabase PostgreSQL tables enforce RLS. `SUPABASE_SERVICE_ROLE_KEY`
   never leaves server-only modules.

## Reporting Security Vulnerabilities

Report platform security issues privately to `security@consinzo.internal` (do not open
public issues).
