import type { MetadataRoute } from "next";
import { listPublishedChallenges } from "@/lib/challenges";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000";
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

  return [...staticRoutes, ...challengeRoutes];
}
