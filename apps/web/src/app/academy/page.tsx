import { GraduationCap } from "lucide-react";
import { AcademyTracks } from "@/components/academy-tracks";
import { LEARNING_PATHS } from "@/lib/knowledge";

export default function AcademyPage() {
  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6">
      <div className="border-b border-zinc-200 pb-6">
        <div className="inline-flex items-center gap-1.5 text-xs font-mono uppercase tracking-wider text-zinc-500">
          <GraduationCap className="h-4 w-4 text-blue-700" />
          Developer Academy
        </div>
        <h1 className="mt-2 text-2xl font-semibold text-zinc-950">
          Structured Engineering Tracks
        </h1>
        <p className="mt-1 text-sm text-zinc-600 max-w-3xl">
          Follow curated challenge tracks from token standards to DeFi protocol invariants and
          exploit defense. Achievements are awarded exclusively from server-verified passes.
        </p>
      </div>

      <AcademyTracks paths={LEARNING_PATHS} />
    </div>
  );
}
