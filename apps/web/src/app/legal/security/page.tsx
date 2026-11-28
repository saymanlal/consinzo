import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage } from "@/components/marketing/legal";
import { CONTACT, pageMetadata } from "@/lib/site";

export const metadata: Metadata = pageMetadata({
  title: "Security Policy",
  description:
    "How CONSINZO treats submitted code, protects hidden test suites, and how to report a vulnerability.",
  path: "/legal/security",
});

export default function SecurityPolicyPage() {
  return (
    <LegalPage
      current="/legal/security"
      title="Platform Security Policy"
      lead="Every submission is treated as hostile. Here is what that means in practice."
      sections={[
        {
          heading: "Untrusted code",
          body: (
            <p>
              All submitted code is treated as untrusted. Execution is subject to strict snapshot
              size caps (256 KB), timeouts (15s), output sanitization, and hourly submission
              quotas.
            </p>
          ),
        },
        {
          heading: "Hidden suites and solutions",
          body: (
            <p>
              Hidden test suites and reference solutions are stored server-side and excluded from
              public API responses.
            </p>
          ),
        },
        {
          heading: "Reporting a vulnerability",
          body: (
            <p>
              Report security issues privately
              {CONTACT.securityEmail ? (
                <>
                  {" "}to{" "}
                  <a href={`mailto:${CONTACT.securityEmail}`} className="cz-focus break-all rounded text-zinc-200 underline hover:text-white">
                    {CONTACT.securityEmail}
                  </a>
                </>
              ) : (
                <>
                  {" "}through the{" "}
                  <Link href="/contact" className="cz-focus rounded text-zinc-200 underline hover:text-white">
                    contact form
                  </Link>{" "}
                  with the topic “Security report”
                </>
              )}
              . Please do not open public issues for vulnerabilities.
            </p>
          ),
        },
      ]}
    />
  );
}
