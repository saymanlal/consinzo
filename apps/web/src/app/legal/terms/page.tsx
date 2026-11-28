import type { Metadata } from "next";
import { LegalPage } from "@/components/marketing/legal";
import { pageMetadata } from "@/lib/site";

export const metadata: Metadata = pageMetadata({
  title: "Terms of Service",
  description:
    "Terms of Service and intellectual property terms for the CONSINZO smart-contract engineering platform.",
  path: "/legal/terms",
});

export default function TermsPage() {
  return (
    <LegalPage
      current="/legal/terms"
      title="Terms of Service & Intellectual Property"
      lead="The rules for using CONSINZO, and who owns what."
      updated="2026-11-26"
      sections={[
        {
          heading: "Ownership",
          body: (
            <p>
              CONSINZO and all proprietary challenge specifications, hidden evaluation suites,
              reference solutions, platform code, and security missions remain the exclusive
              intellectual property of CONSINZO.
            </p>
          ),
        },
        {
          heading: "What you may do",
          body: (
            <p>
              Authorized users may submit code solutions for personal learning and competition
              participation.
            </p>
          ),
        },
        {
          heading: "What you may not do",
          body: (
            <p>
              Redistributing hidden tests, scraping solutions, or attempting to probe or escape
              evaluation runners is strictly prohibited.
            </p>
          ),
        },
      ]}
    />
  );
}
