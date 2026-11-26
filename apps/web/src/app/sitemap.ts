import type { MetadataRoute } from "next";
import { listPublishedChallenges } from "@/lib/challenges";
import { KNOWLEDGE_ENTRIES } from "@/lib/knowledge";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl =
    process.env.NEXT_PUBLIC_APP_URL ||
    (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : "http://localhost:3000");
  const staticRoutes = [
    "",
    "/challenges",
    "/security",
    "/protocols",
    "/ecosystems",
    "/knowledge",
    "/competitions",
    "/academy",
    "/docs",
    "/about",
  ].map((route) => ({
    url: `${baseUrl}${route}`,
    lastModified: new Date(),
  }));

  const challengeRoutes = listPublishedChallenges().map((c) => ({
    url: `${baseUrl}/challenges/${c.slug}`,
    lastModified: new Date(),
  }));

  const knowledgeRoutes = KNOWLEDGE_ENTRIES.map((k) => ({
    url: `${baseUrl}/knowledge/${k.slug}`,
    lastModified: new Date(),
  }));

  return [...staticRoutes, ...challengeRoutes, ...knowledgeRoutes];
}
