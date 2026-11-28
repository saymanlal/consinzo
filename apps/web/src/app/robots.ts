import type { MetadataRoute } from "next";
import { getSiteUrl } from "@/lib/site";

const ALLOW = ["/", "/challenges", "/ecosystems", "/knowledge", "/docs"];
const DISALLOW = ["/api/", "/admin/", "/dashboard/", "/settings/"];

// Answer-engine crawlers are named explicitly so public pages stay eligible for AI answers
// even if the wildcard rule is tightened later. Private surfaces stay disallowed for all.
const ANSWER_ENGINE_AGENTS = [
  "GPTBot",
  "OAI-SearchBot",
  "ChatGPT-User",
  "ClaudeBot",
  "Claude-SearchBot",
  "Claude-User",
  "PerplexityBot",
  "Perplexity-User",
  "Google-Extended",
  "Applebot-Extended",
];

export default function robots(): MetadataRoute.Robots {
  const baseUrl = getSiteUrl();
  return {
    rules: [
      { userAgent: "*", allow: ALLOW, disallow: DISALLOW },
      { userAgent: ANSWER_ENGINE_AGENTS, allow: ALLOW, disallow: DISALLOW },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
    host: baseUrl,
  };
}
