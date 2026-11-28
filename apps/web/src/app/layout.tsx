import type { Metadata, Viewport } from "next";
import React from "react";
import { AppProviders } from "@/components/providers";
import { AppShell } from "@/components/app-shell";
import { SITE, buildSiteJsonLd, getSiteUrl } from "@/lib/site";
import "./globals.css";

// favicon.ico, icon.svg, apple-icon.png, opengraph-image.png and twitter-image.png in this
// directory are picked up by Next.js file conventions and linked automatically. Do not set
// `icons` here (it replaces the file-based icon links), and do not set a canonical/og:url
// here either: root-layout values are inherited by every page.
export const metadata: Metadata = {
  metadataBase: new URL(getSiteUrl()),
  title: {
    default: SITE.title,
    template: `%s | ${SITE.name}`,
  },
  description: SITE.description,
  applicationName: SITE.name,
  keywords: [...SITE.keywords],
  authors: [{ name: SITE.name }],
  creator: SITE.name,
  publisher: SITE.name,
  category: "technology",
  openGraph: {
    type: "website",
    siteName: SITE.name,
    title: SITE.title,
    description: SITE.description,
    locale: SITE.locale,
  },
  twitter: {
    card: "summary_large_image",
    title: SITE.title,
    description: SITE.description,
  },
  appleWebApp: { capable: true, title: SITE.name, statusBarStyle: "default" },
  formatDetection: { telephone: false },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#FFFFFF" },
    { media: "(prefers-color-scheme: dark)", color: SITE.themeColor },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  // Static, server-built object: escape "<" so it can never close the script tag.
  const jsonLd = JSON.stringify(buildSiteJsonLd()).replace(/</g, "\\u003c");
  return (
    <html lang="en">
      <body>
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: jsonLd }} />
        <AppProviders>
          <AppShell>{children}</AppShell>
        </AppProviders>
      </body>
    </html>
  );
}
