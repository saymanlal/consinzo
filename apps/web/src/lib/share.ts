/**
 * Share targets and caption drafts. Captions are generated from facts the profile already
 * shows (name, score, counts, badge) so nothing is claimed that is not verified.
 */
export type SharePlatformId =
  | "x"
  | "linkedin"
  | "farcaster"
  | "reddit"
  | "bluesky"
  | "lens"
  | "threads"
  | "telegram"
  | "whatsapp";

export interface SharePlatform {
  id: SharePlatformId;
  label: string;
  /** Character budget for the post text, URL included where the network counts it. */
  limit: number;
  /** Whether hashtags are idiomatic there. */
  hashtags: boolean;
  /** Builds the compose URL. */
  compose: (text: string, url: string, title: string) => string;
}

const e = encodeURIComponent;

export const SHARE_PLATFORMS: SharePlatform[] = [
  {
    id: "x",
    label: "X",
    limit: 280,
    hashtags: true,
    compose: (text, url) => `https://x.com/intent/post?text=${e(text)}&url=${e(url)}`,
  },
  {
    id: "linkedin",
    label: "LinkedIn",
    limit: 1300,
    hashtags: true,
    compose: (text, url) =>
      `https://www.linkedin.com/feed/?shareActive=true&text=${e(`${text}\n\n${url}`)}`,
  },
  {
    id: "farcaster",
    label: "Farcaster",
    limit: 320,
    hashtags: false,
    compose: (text, url) => `https://warpcast.com/~/compose?text=${e(text)}&embeds[]=${e(url)}`,
  },
  {
    id: "reddit",
    label: "Reddit",
    limit: 300,
    hashtags: false,
    compose: (_text, url, title) => `https://www.reddit.com/submit?url=${e(url)}&title=${e(title)}`,
  },
  {
    id: "bluesky",
    label: "Bluesky",
    limit: 300,
    hashtags: true,
    compose: (text, url) => `https://bsky.app/intent/compose?text=${e(`${text} ${url}`)}`,
  },
  {
    id: "lens",
    label: "Lens",
    limit: 500,
    hashtags: true,
    compose: (text, url) => `https://hey.xyz/?text=${e(text)}&url=${e(url)}`,
  },
  {
    id: "threads",
    label: "Threads",
    limit: 500,
    hashtags: false,
    compose: (text, url) => `https://www.threads.net/intent/post?text=${e(`${text} ${url}`)}`,
  },
  {
    id: "telegram",
    label: "Telegram",
    limit: 1000,
    hashtags: false,
    compose: (text, url) => `https://t.me/share/url?url=${e(url)}&text=${e(text)}`,
  },
  {
    id: "whatsapp",
    label: "WhatsApp",
    limit: 1000,
    hashtags: false,
    compose: (text, url) => `https://wa.me/?text=${e(`${text} ${url}`)}`,
  },
];

export interface ShareSubject {
  displayName: string;
  username: string;
  totalPoints: number;
  challengesCompleted: number;
  securityMissionsCompleted: number;
  badgeCount: number;
  /** Set when a single badge is being shared. */
  badge?: { title: string; feat: string; track: string };
}

export type CaptionTone = "proud" | "technical" | "short";

export const CAPTION_TONES: Array<{ id: CaptionTone; label: string }> = [
  { id: "proud", label: "Celebrate" },
  { id: "technical", label: "Technical" },
  { id: "short", label: "Short" },
];

const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`;

function statsLine(s: ShareSubject): string {
  const parts: string[] = [];
  if (s.challengesCompleted > 0) parts.push(`${plural(s.challengesCompleted, "challenge")} passed`);
  if (s.securityMissionsCompleted > 0) {
    parts.push(`${plural(s.securityMissionsCompleted, "security mission")} cleared`);
  }
  if (s.totalPoints > 0) parts.push(`${s.totalPoints.toLocaleString("en-US")} verified points`);
  return parts.join(" · ");
}

function hashtagsFor(s: ShareSubject): string {
  const tags = ["#web3", "#smartcontracts"];
  if (s.badge?.track === "Security" || (!s.badge && s.securityMissionsCompleted > 0)) {
    tags.push("#web3security");
  } else if (s.badge?.track === "DeFi") tags.push("#DeFi");
  else if (s.badge?.track === "Ecosystem") tags.push("#NEAR");
  else tags.push("#Solidity");
  tags.push("#buildinpublic");
  return tags.join(" ");
}

/** The post body, before any hashtags and without the link. */
function body(s: ShareSubject, tone: CaptionTone, platform: SharePlatform): string {
  const stats = statsLine(s);
  const long = platform.limit >= 500;

  if (s.badge) {
    const { title, feat } = s.badge;
    if (tone === "short") return `New badge on CONSINZO: ${title} 🏅`;
    if (tone === "technical") {
      return [
        `Earned “${title}” on CONSINZO.`,
        `What it took: I ${feat}. Code is compiled and run for real, then scored against hidden tests, so a pass means the contract holds.`,
        long && stats ? `So far: ${stats}.` : "",
      ]
        .filter(Boolean)
        .join("\n\n");
    }
    return [
      `Just unlocked the “${title}” badge on CONSINZO 🏅`,
      `I ${feat}.`,
      long && stats ? `Running total: ${stats}.` : "",
      long ? "On to the next one." : "",
    ]
      .filter(Boolean)
      .join("\n\n");
  }

  if (tone === "short") {
    return stats ? `My CONSINZO engineering profile: ${stats}.` : "My CONSINZO engineering profile is live.";
  }
  if (tone === "technical") {
    return [
      "My smart-contract engineering record on CONSINZO.",
      stats ? `${stats}${s.badgeCount > 0 ? ` · ${plural(s.badgeCount, "badge")}` : ""}.` : "",
      "Every pass is real compilation plus hidden-suite evaluation, not a quiz.",
    ]
      .filter(Boolean)
      .join("\n\n");
  }
  return [
    "Building my smart-contract engineering record in public on CONSINZO 🛠️",
    stats ? `${stats}.` : "Just getting started.",
    long ? "Build. Test. Break. Master." : "",
  ]
    .filter(Boolean)
    .join("\n\n");
}

function clamp(text: string, max: number): string {
  if (text.length <= max) return text;
  return `${text.slice(0, Math.max(0, max - 1)).trimEnd()}…`;
}

/** A ready-to-post caption for one network, trimmed to its length budget. */
export function buildCaption(
  subject: ShareSubject,
  platformId: SharePlatformId,
  tone: CaptionTone,
  url: string
): string {
  const platform = SHARE_PLATFORMS.find((p) => p.id === platformId)!;
  const tags = platform.hashtags ? hashtagsFor(subject) : "";
  // X shortens every link to 23 characters; elsewhere count the real URL.
  const urlCost = (platformId === "x" ? 23 : url.length) + 2;
  const tagCost = tags ? tags.length + 2 : 0;
  const text = clamp(body(subject, tone, platform), platform.limit - urlCost - tagCost);
  return tags ? `${text}\n\n${tags}` : text;
}

/** Reddit posts are a title plus a link, so it gets a headline instead of a caption. */
export function buildShareTitle(subject: ShareSubject): string {
  return subject.badge
    ? `Earned the “${subject.badge.title}” badge on CONSINZO (smart-contract engineering)`
    : `My smart-contract engineering profile on CONSINZO${
        subject.challengesCompleted > 0
          ? `: ${plural(subject.challengesCompleted, "challenge")} passed`
          : ""
      }`;
}
