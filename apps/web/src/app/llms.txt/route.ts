import { ECOSYSTEM_REGISTRY, SUPPORT_LEVEL_LABELS } from "@consinzo/ecosystem-registry";
import { listPublishedChallenges } from "@/lib/challenges";
import { KNOWLEDGE_ENTRIES } from "@/lib/knowledge";
import { PUBLIC_ROUTES, SITE, getSiteUrl } from "@/lib/site";

// llms.txt (https://llmstxt.org): a plain-markdown index of the public site for answer
// engines. Built from the same registries as the UI so it never drifts from real content.
export const dynamic = "force-static";

const oneLine = (text: string) => text.replace(/\s+/g, " ").trim();

export function GET() {
  const baseUrl = getSiteUrl();
  const challenges = listPublishedChallenges();
  const lines: string[] = [
    `# ${SITE.name}`,
    "",
    `> ${SITE.tagline}. ${SITE.description}`,
    "",
    `Logo: ${baseUrl}${SITE.logo.svg} (SVG), ${baseUrl}${SITE.logo.png} (PNG)`,
    "",
    "## Sections",
    "",
    ...PUBLIC_ROUTES.map((r) => `- [${r.label}](${baseUrl}${r.path || "/"}): ${r.summary}`),
    "",
    "## Ecosystems",
    "",
    ...ECOSYSTEM_REGISTRY.map(
      (e) =>
        `- ${e.name} (${e.primaryLanguages.join(", ")}): support level ${e.supportLevel} — ${SUPPORT_LEVEL_LABELS[e.supportLevel].name}`
    ),
    "",
    `## Challenges (${challenges.length})`,
    "",
    ...challenges.map(
      (c) =>
        `- [${c.title}](${baseUrl}/challenges/${c.slug}): ${oneLine(c.description)} (${c.ecosystem}, ${c.language}, ${c.difficulty}${c.is_security_mission ? ", security mission" : ""})`
    ),
    "",
    `## Knowledge (${KNOWLEDGE_ENTRIES.length})`,
    "",
    ...KNOWLEDGE_ENTRIES.map(
      (k) => `- [${k.title}](${baseUrl}/knowledge/${k.slug}): ${oneLine(k.summary)}`
    ),
    "",
    "## Notes",
    "",
    "- CONSINZO is proprietary software. Hidden evaluation suites and reference solutions are not public.",
    "- Account, dashboard, admin, and API routes are not intended for indexing.",
    "",
  ];

  return new Response(lines.join("\n"), {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "public, max-age=3600",
    },
  });
}
