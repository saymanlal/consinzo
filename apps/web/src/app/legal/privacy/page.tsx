import type { Metadata } from "next";
import { LegalPage } from "@/components/marketing/legal";
import { pageMetadata } from "@/lib/site";

export const metadata: Metadata = pageMetadata({
  title: "Privacy Policy",
  description:
    "What account data CONSINZO collects, how sign-in sessions and wallets are handled, and what is never collected.",
  path: "/legal/privacy",
});

export default function PrivacyPolicyPage() {
  return (
    <LegalPage
      current="/legal/privacy"
      title="Privacy Policy"
      lead="What we collect, why, and what we never see."
      updated="2026-11-28"
      sections={[
        {
          heading: "Account data",
          body: (
            <p>
              CONSINZO collects only the account metadata required for authentication and developer
              progression: the identifier you sign in with (email address, phone number, wallet
              address, or the profile returned by Google or GitHub), username, display name,
              optional GitHub and website links, and challenge submission records.
            </p>
          ),
        },
        {
          heading: "Wallets",
          body: (
            <>
              <p>
                When you sign in with a wallet we store your public wallet address and verify a
                signed message. We never receive, store or transmit a private key or recovery
                phrase.
              </p>
              <p>
                If you create a wallet on CONSINZO, it is generated in your browser. The recovery
                phrase stays on your device, optionally encrypted with a password you choose. We
                cannot recover it for you.
              </p>
            </>
          ),
        },
        {
          heading: "Guest mode",
          body: (
            <p>
              Guests can run public tests without an account. Guest code is kept in your browser
              and is not saved to a profile. We count guest runs per network address to limit
              abuse.
            </p>
          ),
        },
        {
          heading: "Cookies and tracking",
          body: (
            <p>
              Authentication sessions use strictly necessary HTTP-only cookies. No third-party ad
              trackers or data brokers are integrated.
            </p>
          ),
        },
        {
          heading: "Messages you send us",
          body: (
            <p>
              Messages sent through the contact form are stored with the name and email address
              you provide so that we can reply.
            </p>
          ),
        },
      ]}
    />
  );
}
