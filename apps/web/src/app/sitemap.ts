import type { MetadataRoute } from "next";
import { listPublishedChallenges } from "@/lib/challenges";
import { KNOWLEDGE_ENTRIES } from "@/lib/knowledge";
import { PUBLIC_ROUTES, getSiteUrl } from "@/lib/site";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = getSiteUrl();
  const staticRoutes = PUBLIC_ROUTES.map((route) => ({
    url: `${baseUrl}${route.path}`,
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
