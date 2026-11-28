/**
 * Single source of truth for brand + SEO/AEO metadata (layout metadata, JSON-LD,
 * manifest, robots, sitemap, llms.txt).
 */
export const SITE = {
  name: "CONSINZO",
  tagline: "The Engineering Platform",
  statement: "Build. Test. Break. Master.",
  title: "CONSINZO — The Engineering Platform",
  description:
    "Build. Test. Break. Master. Multi-ecosystem blockchain smart-contract engineering, native compilation, automated testing, and security training.",
  keywords: [
    "CONSINZO",
    "smart contract engineering",
    "blockchain engineering platform",
    "Solidity challenges",
    "EVM",
    "NEAR smart contracts",
    "smart contract security training",
    "smart contract auditing practice",
    "DeFi protocol engineering",
    "Foundry tests",
    "web3 developer training",
  ],
  themeColor: "#09090B",
  backgroundColor: "#FAFAFA",
  locale: "en_US",
  logo: {
    svg: "/brand/consinzo-mark.svg",
    png: "/icons/icon-512.png",
    horizontalSvg: "/brand/consinzo-logo-horizontal.svg",
  },
} as const;

const env = (value: string | undefined) => (value && value.trim() ? value.trim() : undefined);

/**
 * Public contact channels. Each one is shown only when its variable is set, so the site
 * never advertises an address or profile that does not exist.
 */
export const CONTACT = {
  email: env(process.env.NEXT_PUBLIC_CONTACT_EMAIL),
  securityEmail: env(process.env.NEXT_PUBLIC_SECURITY_EMAIL),
  socials: [
    { id: "x", label: "X", url: env(process.env.NEXT_PUBLIC_SOCIAL_X) },
    { id: "github", label: "GitHub", url: env(process.env.NEXT_PUBLIC_SOCIAL_GITHUB) },
    { id: "discord", label: "Discord", url: env(process.env.NEXT_PUBLIC_SOCIAL_DISCORD) },
    { id: "telegram", label: "Telegram", url: env(process.env.NEXT_PUBLIC_SOCIAL_TELEGRAM) },
    { id: "farcaster", label: "Farcaster", url: env(process.env.NEXT_PUBLIC_SOCIAL_FARCASTER) },
    { id: "linkedin", label: "LinkedIn", url: env(process.env.NEXT_PUBLIC_SOCIAL_LINKEDIN) },
  ].filter((s): s is { id: string; label: string; url: string } => Boolean(s.url)),
};

/** Per-page metadata with a self-referencing canonical and matching social cards. */
export function pageMetadata(input: {
  title: string;
  description: string;
  path: string;
  noIndex?: boolean;
}) {
  return {
    title: input.title,
    description: input.description,
    alternates: { canonical: input.path },
    openGraph: {
      type: "website" as const,
      siteName: SITE.name,
      title: `${input.title} | ${SITE.name}`,
      description: input.description,
      url: input.path,
      locale: SITE.locale,
    },
    twitter: {
      card: "summary_large_image" as const,
      title: `${input.title} | ${SITE.name}`,
      description: input.description,
    },
    ...(input.noIndex ? { robots: { index: false, follow: false } } : {}),
  };
}

/** Absolute origin of the deployment, without a trailing slash. */
export function getSiteUrl(): string {
  const explicit = process.env.NEXT_PUBLIC_APP_URL;
  if (explicit) return explicit.replace(/\/+$/, "");
  if (process.env.VERCEL_PROJECT_PRODUCTION_URL) {
    return `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`;
  }
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  return "http://localhost:3000";
}

export function absoluteUrl(path = "/"): string {
  return `${getSiteUrl()}${path.startsWith("/") ? path : `/${path}`}`;
}

/** Public, indexable top-level routes (shared by sitemap.xml and llms.txt). */
export const PUBLIC_ROUTES = [
  { path: "", label: "Overview", summary: "Platform overview and verified inventory." },
  {
    path: "/challenges",
    label: "Challenge Codex",
    summary: "Catalogue of smart-contract engineering challenges with public and hidden test suites.",
  },
  {
    path: "/security",
    label: "Security Arena",
    summary: "Exploit and patch missions covering real smart-contract vulnerability classes.",
  },
  {
    path: "/protocols",
    label: "Protocol Lab",
    summary: "Interactive protocol simulators and protocol implementation labs.",
  },
  {
    path: "/ecosystems",
    label: "Ecosystem Hub",
    summary: "Supported blockchain ecosystems, pinned toolchains, and support levels.",
  },
  {
    path: "/knowledge",
    label: "Knowledge Hub",
    summary: "Reference entries on smart-contract and protocol engineering concepts.",
  },
  {
    path: "/competitions",
    label: "Competitions",
    summary: "Contests, team registration, and leaderboards.",
  },
  { path: "/academy", label: "Academy", summary: "Guided learning tracks." },
  { path: "/docs", label: "Documentation", summary: "Technical documentation for the platform." },
  { path: "/about", label: "About", summary: "What CONSINZO is and who it is for." },
  { path: "/contact", label: "Contact", summary: "Send the team a message." },
] as const;

/** schema.org graph describing the organisation, the site and the application. */
export function buildSiteJsonLd() {
  const url = getSiteUrl();
  const logo = {
    "@type": "ImageObject",
    "@id": `${url}/#logo`,
    url: `${url}${SITE.logo.png}`,
    contentUrl: `${url}${SITE.logo.png}`,
    width: 512,
    height: 512,
    caption: SITE.name,
  };
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": `${url}/#organization`,
        name: SITE.name,
        url,
        slogan: SITE.statement,
        description: SITE.description,
        logo,
        image: { "@id": `${url}/#logo` },
      },
      {
        "@type": "WebSite",
        "@id": `${url}/#website`,
        name: SITE.name,
        alternateName: SITE.title,
        url,
        description: SITE.description,
        inLanguage: "en",
        publisher: { "@id": `${url}/#organization` },
      },
      {
        "@type": "WebApplication",
        "@id": `${url}/#application`,
        name: SITE.name,
        url,
        description: SITE.description,
        applicationCategory: "DeveloperApplication",
        operatingSystem: "Any (web browser)",
        browserRequirements: "Requires JavaScript",
        image: `${url}/opengraph-image.png`,
        publisher: { "@id": `${url}/#organization` },
      },
    ],
  };
}
