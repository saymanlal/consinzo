import { BookOpen } from "lucide-react";
import { KnowledgeExplorer } from "@/components/knowledge-explorer";
import { KNOWLEDGE_ENTRIES } from "@/lib/knowledge";

export default function KnowledgePage() {
  const ecosystemsCovered = new Set(KNOWLEDGE_ENTRIES.map((e) => e.ecosystemId)).size;

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6">
      <div className="border-b border-zinc-200 pb-6">
        <div className="inline-flex items-center gap-1.5 text-xs font-mono uppercase tracking-wider text-zinc-500">
          <BookOpen className="h-4 w-4 text-blue-700" />
          Curated Multi-Chain Knowledge Hub
        </div>
        <h1 className="mt-2 text-2xl font-semibold text-zinc-950">
          Versioned Standards, Languages &amp; Security References
        </h1>
        <p className="mt-1 text-sm text-zinc-600 max-w-3xl">
          Every article tracks explicit toolchain versions, official canonical sources, and verification
          dates across all {ecosystemsCovered} supported blockchain ecosystems.
        </p>
      </div>

      <KnowledgeExplorer entries={KNOWLEDGE_ENTRIES} />
    </div>
  );
}
