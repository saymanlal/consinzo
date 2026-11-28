import type { Metadata } from "next";
import Link from "next/link";
import { BookOpen, LifeBuoy, Mail, ShieldAlert } from "lucide-react";
import { ContactForm } from "@/components/contact-form";
import { Container, DarkBand, PageHero } from "@/components/marketing/blocks";
import { Reveal } from "@/components/marketing/motion";
import { CONTACT, pageMetadata } from "@/lib/site";

export const metadata: Metadata = pageMetadata({
  title: "Contact",
  description:
    "Contact the CONSINZO team about your account, a challenge, partnerships, press, or a security report.",
  path: "/contact",
});

export default function ContactPage() {
  return (
    <DarkBand>
      <PageHero
        eyebrow="Contact"
        title={
          <>
            Talk to the people who <span className="cz-gradient-text">build it</span>
          </>
        }
        lead="Questions, partnership ideas, a bug in a challenge, or a security report. Pick a topic and write to us."
      />
      <Container className="grid gap-8 pb-24 lg:grid-cols-[1.25fr_0.75fr]">
        <Reveal>
          <ContactForm />
        </Reveal>
        <div className="space-y-4">
          {CONTACT.email ? (
            <Reveal delay={80} className="cz-card p-6">
              <Mail className="h-5 w-5 text-cyan-300" />
              <h2 className="mt-3 text-sm font-semibold text-white">Email</h2>
              <a href={`mailto:${CONTACT.email}`} className="cz-focus mt-1 block break-all rounded text-sm text-zinc-300 hover:text-white">
                {CONTACT.email}
              </a>
            </Reveal>
          ) : null}
          <Reveal delay={140} className="cz-card p-6">
            <ShieldAlert className="h-5 w-5 text-rose-300" />
            <h2 className="mt-3 text-sm font-semibold text-white">Security reports</h2>
            <p className="mt-1 text-sm leading-relaxed text-zinc-400">
              Found a vulnerability in the platform? Report it privately
              {CONTACT.securityEmail ? (
                <>
                  {" "}to{" "}
                  <a href={`mailto:${CONTACT.securityEmail}`} className="cz-focus break-all rounded text-zinc-200 underline hover:text-white">
                    {CONTACT.securityEmail}
                  </a>
                </>
              ) : (
                <> using the form with the topic “Security report”</>
              )}
              . Please do not post it publicly. See the{" "}
              <Link href="/legal/security" className="cz-focus rounded text-zinc-200 underline hover:text-white">
                security policy
              </Link>
              .
            </p>
          </Reveal>
          <Reveal delay={200} className="cz-card p-6">
            <LifeBuoy className="h-5 w-5 text-violet-300" />
            <h2 className="mt-3 text-sm font-semibold text-white">Before you write</h2>
            <ul className="mt-2 space-y-2 text-sm text-zinc-400">
              <li>
                <Link href="/docs" className="cz-focus inline-flex items-center gap-1.5 rounded hover:text-white">
                  <BookOpen className="h-3.5 w-3.5" /> Documentation
                </Link>
              </li>
              <li>
                <Link href="/ecosystems" className="cz-focus rounded hover:text-white">
                  Which ecosystems can run code today
                </Link>
              </li>
            </ul>
          </Reveal>
          {CONTACT.socials.length > 0 ? (
            <Reveal delay={260} className="cz-card p-6">
              <h2 className="text-sm font-semibold text-white">Elsewhere</h2>
              <ul className="mt-3 flex flex-wrap gap-2">
                {CONTACT.socials.map((s) => (
                  <li key={s.id}>
                    <a href={s.url} target="_blank" rel="noopener noreferrer me" className="cz-btn cz-btn-ghost px-3 py-1.5 text-xs">
                      {s.label}
                    </a>
                  </li>
                ))}
              </ul>
            </Reveal>
          ) : null}
        </div>
      </Container>
    </DarkBand>
  );
}
