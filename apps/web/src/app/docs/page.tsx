import { Card } from "@consinzo/ui";

export default function DocsPage() {
  return (
    <div className="mx-auto max-w-4xl px-4 py-10 space-y-6">
      <div className="border-b border-zinc-200 pb-4">
        <h1 className="text-2xl font-semibold text-zinc-950">CONSINZO Technical Documentation</h1>
        <p className="mt-1 text-sm text-zinc-600">
          Local CLI workflow, challenge package schema, execution modes, and REST API v1 reference.
        </p>
      </div>

      <Card className="p-6 space-y-3">
        <h2 className="text-base font-semibold text-zinc-950">Execution Modes</h2>
        <ul className="list-disc list-inside text-xs text-zinc-700 space-y-1.5">
          <li>
            <strong>Mode B (Local CLI &amp; In-Process EVM Runner):</strong> Compiles Solidity
            projects via <code className="font-mono">solc 0.8.28</code> and executes Foundry-compatible
            test contracts via native <code className="font-mono">forge</code> (when installed) or
            bundled <code className="font-mono">@ethereumjs/evm</code>.
          </li>
          <li>
            <strong>Mode C (Remote GitHub Actions Evaluation):</strong> Disabled by default in
            free-tier local deployments unless an isolated evaluation runner without repository
            secret exposure is configured.
          </li>
        </ul>
        <pre className="rounded bg-zinc-950 p-3 font-mono text-xs text-zinc-200 overflow-x-auto">
{`pnpm cli -- doctor
pnpm cli -- compile content/challenges/erc20-token-vault
pnpm cli -- test content/challenges/erc20-token-vault
pnpm validate:challenges`}
        </pre>
      </Card>

      <Card className="p-6 space-y-2 text-xs text-zinc-700">
        <h2 className="text-base font-semibold text-zinc-950">Free-Tier Guardrails</h2>
        <p>Maximum project snapshot: 256 KB across up to 40 files.</p>
        <p>Execution timeout: 15,000 ms per run; sanitized logs capped at 64 KB.</p>
        <p>Hourly submission quota: 20 submissions/hour per authenticated developer.</p>
      </Card>
    </div>
  );
}
