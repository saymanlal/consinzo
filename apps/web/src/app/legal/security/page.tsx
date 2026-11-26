import { Card } from "@consinzo/ui";

export default function SecurityPolicyPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-10 space-y-4">
      <h1 className="text-2xl font-semibold text-zinc-950">Platform Security Policy</h1>
      <Card className="p-6 space-y-3 text-xs leading-relaxed text-zinc-700">
        <p>
          All submitted code is treated as untrusted. Execution is subject to strict snapshot size
          caps (256 KB), timeouts (15s), output sanitization, and hourly submission quotas.
        </p>
        <p>
          Hidden test suites and reference solutions are stored server-side and excluded from
          public API responses. Report security issues privately to security@consinzo.internal.
        </p>
      </Card>
    </div>
  );
}
