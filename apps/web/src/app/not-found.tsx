import Link from "next/link";
import { Container, DarkBand, Eyebrow, LogoOrb } from "@/components/marketing/blocks";

export default function NotFound() {
  return (
    <DarkBand className="min-h-[70vh]">
      <Container className="flex flex-col items-center py-24 text-center">
        <LogoOrb className="w-40 opacity-80" />
        <div className="mt-10">
          <Eyebrow>404 · Not found</Eyebrow>
        </div>
        <h1 className="mt-5 text-4xl font-semibold tracking-tight text-white sm:text-5xl">
          This block was never <span className="cz-gradient-text">mined</span>
        </h1>
        <p className="mt-4 max-w-md text-sm leading-relaxed text-zinc-400 sm:text-base">
          The challenge, ecosystem or page you asked for does not exist, or it has moved.
        </p>
        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Link href="/" className="cz-btn cz-btn-primary">
            Back to overview
          </Link>
          <Link href="/challenges" className="cz-btn cz-btn-ghost">
            Browse challenges
          </Link>
        </div>
      </Container>
    </DarkBand>
  );
}
