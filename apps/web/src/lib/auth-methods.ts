import { getServerEnv } from "./env";

export interface AuthMethodAvailability {
  password: boolean;
  wallet: boolean;
  google: boolean;
  github: boolean;
  emailCode: boolean;
  phone: boolean;
  /** True when one-time codes are shown on screen instead of being delivered (local dev only). */
  devCodes: boolean;
  mode: "supabase" | "local";
}

const on = (v: string | undefined) => v === "true" || v === "1";

/**
 * Which sign-in methods this deployment can actually complete.
 *
 * - Password and wallet always work (wallet needs no third party).
 * - Google, GitHub, email codes and SMS are delivered by Supabase Auth. Each needs the
 *   provider enabled in the Supabase dashboard AND its flag set here, so the UI never
 *   offers a button that would fail.
 * - Without Supabase, email and phone codes are available only outside production, where
 *   the code is returned to the page instead of being sent.
 */
export function getAuthMethodAvailability(): AuthMethodAvailability {
  const env = getServerEnv();
  const supabase = env.isSupabaseConfigured;
  const devCodes = !supabase && process.env.NODE_ENV !== "production";
  return {
    password: true,
    wallet: true,
    google: supabase && on(process.env.CONSINZO_AUTH_GOOGLE),
    github: supabase && on(process.env.CONSINZO_AUTH_GITHUB),
    emailCode: supabase ? on(process.env.CONSINZO_AUTH_EMAIL_CODE) : devCodes,
    phone: supabase ? on(process.env.CONSINZO_AUTH_PHONE) : devCodes,
    devCodes,
    mode: supabase ? "supabase" : "local",
  };
}

/** Only same-site relative paths are accepted as post-login destinations. */
export function safeNextPath(raw: string | null | undefined, fallback = "/dashboard"): string {
  if (!raw || !raw.startsWith("/") || raw.startsWith("//") || raw.includes("\\")) return fallback;
  return raw;
}

/** Public origin of this request, honouring the proxy headers Vercel sets. */
export function getRequestOrigin(req: Request): { origin: string; host: string } {
  const url = new URL(req.url);
  const host = req.headers.get("x-forwarded-host") ?? req.headers.get("host") ?? url.host;
  const proto = req.headers.get("x-forwarded-proto") ?? url.protocol.replace(":", "");
  return { origin: `${proto}://${host}`, host };
}

/** Human list of the sign-in methods this deployment offers, for public copy. */
export function describeSignInMethods(): string {
  const m = getAuthMethodAvailability();
  const names = [
    m.wallet ? "a wallet" : null,
    m.google ? "Google" : null,
    m.github ? "GitHub" : null,
    m.emailCode ? "an email code" : null,
    m.phone ? "a phone code" : null,
    m.password ? "email and password" : null,
  ].filter((n): n is string => Boolean(n));
  if (names.length <= 1) return names[0] ?? "email and password";
  return `${names.slice(0, -1).join(", ")} or ${names[names.length - 1]}`;
}
