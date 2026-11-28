import crypto from "node:crypto";
import { cookies } from "next/headers";
import type { RoleName } from "@consinzo/shared";
import { ConsinzoError } from "@consinzo/shared";
import { getUserProfileById } from "./data-adapter";
import { getServerEnv } from "./env";
import { readDb, writeDb, type StoredUser } from "./store";
import { getSupabaseAdminClient, getSupabaseServerAuthClient } from "./supabase";

export const SESSION_COOKIE_NAME = "consinzo_session";

export interface SessionUser {
  id: string;
  email: string;
  username: string;
  displayName: string;
  roles: RoleName[];
}

export function hashPassword(password: string): string {
  const salt = crypto.randomBytes(16).toString("hex");
  const derived = crypto.scryptSync(password, salt, 64).toString("hex");
  return `${salt}:${derived}`;
}

export function verifyPassword(password: string, storedHash: string): boolean {
  const [salt, keyHex] = storedHash.split(":");
  if (!salt || !keyHex) return false;
  const derived = crypto.scryptSync(password, salt, 64);
  const expected = Buffer.from(keyHex, "hex");
  if (derived.length !== expected.length) return false;
  return crypto.timingSafeEqual(derived, expected);
}

export function signSessionToken(payload: { userId: string; exp: number }): string {
  const { authSecret } = getServerEnv();
  const body = Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");
  const sig = crypto.createHmac("sha256", authSecret).update(body).digest("base64url");
  return `${body}.${sig}`;
}

export function verifySessionToken(token: string): { userId: string; exp: number } | null {
  const [body, sig] = token.split(".");
  if (!body || !sig) return null;
  const { authSecret } = getServerEnv();
  const expectedSig = crypto.createHmac("sha256", authSecret).update(body).digest("base64url");
  const sigBuf = Buffer.from(sig);
  const expBuf = Buffer.from(expectedSig);
  if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) {
    return null;
  }
  try {
    const parsed = JSON.parse(Buffer.from(body, "base64url").toString("utf8")) as {
      userId: string;
      exp: number;
    };
    if (!parsed.userId || typeof parsed.exp !== "number" || Date.now() > parsed.exp) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

export function toSessionUser(u: StoredUser): SessionUser {
  return {
    id: u.id,
    email: u.email,
    username: u.username,
    displayName: u.displayName,
    roles: u.roles,
  };
}

export async function getSessionUser(): Promise<SessionUser | null> {
  const env = getServerEnv();
  if (env.isSupabaseConfigured) {
    const supabaseAuth = await getSupabaseServerAuthClient();
    if (supabaseAuth) {
      const {
        data: { user },
      } = await supabaseAuth.auth.getUser();
      if (user) {
        const profile = await getUserProfileById(user.id);
        if (profile) {
          return {
            id: profile.id,
            email: profile.email || user.email || "",
            username: profile.username,
            displayName: profile.displayName,
            roles: profile.roles,
          };
        }
      }
      return null;
    }
  }

  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE_NAME)?.value;
  if (!token) return null;
  const verified = verifySessionToken(token);
  if (!verified) return null;
  const db = readDb();
  const user = db.users.find((u) => u.id === verified.userId);
  return user ? toSessionUser(user) : null;
}

export async function requireSessionUser(): Promise<SessionUser> {
  const user = await getSessionUser();
  if (!user) {
    throw new ConsinzoError("UNAUTHORIZED", "Authentication required.", 401);
  }
  return user;
}

export async function requireAdminRole(allowedRoles: RoleName[]): Promise<SessionUser> {
  const user = await requireSessionUser();
  const hasRole = user.roles.some((r) => allowedRoles.includes(r));
  if (!hasRole) {
    throw new ConsinzoError(
      "FORBIDDEN",
      "Insufficient permissions for this administrative resource.",
      403
    );
  }
  return user;
}

export function createUserAccount(input: {
  email: string;
  username: string;
  displayName: string;
  password: string;
}): StoredUser {
  const db = readDb();
  const normEmail = input.email.trim().toLowerCase();
  const normUsername = input.username.trim().toLowerCase();

  if (db.users.some((u) => u.email === normEmail)) {
    throw new ConsinzoError("EMAIL_EXISTS", "An account with this email already exists.", 409);
  }
  if (db.users.some((u) => u.username === normUsername)) {
    throw new ConsinzoError("USERNAME_EXISTS", "This username is already taken.", 409);
  }

  const user: StoredUser = {
    id: crypto.randomUUID(),
    email: normEmail,
    username: normUsername,
    displayName: input.displayName.trim(),
    bio: "",
    githubUrl: "",
    websiteUrl: "",
    passwordHash: hashPassword(input.password),
    roles: ["developer"],
    totalPoints: 0,
    challengesCompleted: 0,
    securityMissionsCompleted: 0,
    createdAt: new Date().toISOString(),
  };

  db.users.push(user);
  writeDb(db);
  return user;
}

export async function registerSupabaseAccount(input: {
  email: string;
  username: string;
  displayName: string;
  password: string;
}): Promise<SessionUser> {
  const admin = getSupabaseAdminClient();
  const authClient = await getSupabaseServerAuthClient();
  if (!admin || !authClient) {
    throw new ConsinzoError("SUPABASE_UNAVAILABLE", "Supabase is not configured.", 500);
  }

  const normEmail = input.email.trim().toLowerCase();
  const normUsername = input.username.trim().toLowerCase();

  const { data: existingUsername } = await admin
    .from("profiles")
    .select("id")
    .eq("username", normUsername)
    .maybeSingle();
  if (existingUsername) {
    throw new ConsinzoError("USERNAME_EXISTS", "This username is already taken.", 409);
  }

  const { data: created, error } = await admin.auth.admin.createUser({
    email: normEmail,
    password: input.password,
    email_confirm: true,
    user_metadata: { username: normUsername, display_name: input.displayName.trim() },
  });

  if (error || !created.user) {
    throw new ConsinzoError(
      "REGISTRATION_FAILED",
      error?.message ?? "Unable to register user.",
      400
    );
  }

  await admin.from("profiles").insert({
    id: created.user.id,
    username: normUsername,
    display_name: input.displayName.trim(),
  });

  const { data: devRole } = await admin
    .from("roles")
    .select("id")
    .eq("name", "developer")
    .maybeSingle();
  if (devRole?.id) {
    await admin.from("user_roles").insert({
      user_id: created.user.id,
      role_id: devRole.id,
    });
  }

  // Sign in so SSR cookies are set on response
  await authClient.auth.signInWithPassword({ email: normEmail, password: input.password });

  return {
    id: created.user.id,
    email: normEmail,
    username: normUsername,
    displayName: input.displayName.trim(),
    roles: ["developer"],
  };
}

// ───────────────────────── Additional sign-in methods ─────────────────────────

const SESSION_TTL_SECONDS = 7 * 24 * 60 * 60;

/** Domain used for placeholder emails of wallet accounts in Supabase. Not deliverable. */
export const SYNTHETIC_EMAIL_DOMAIN = "@wallet.consinzo.invalid";

export function maskPhone(phone: string): string {
  return phone.length <= 4 ? phone : `${phone.slice(0, 3)}${"•".repeat(phone.length - 5)}${phone.slice(-2)}`;
}

/** Sets the local-mode session cookie on a response. */
export function setLocalSessionCookie(
  res: { cookies: { set: (name: string, value: string, options: Record<string, unknown>) => unknown } },
  userId: string
) {
  const token = signSessionToken({ userId, exp: Date.now() + SESSION_TTL_SECONDS * 1000 });
  res.cookies.set(SESSION_COOKIE_NAME, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: SESSION_TTL_SECONDS,
  });
}

/** HMAC-signed short-lived payload (wallet nonces). `typ` keeps it from being used as a session. */
export function signTypedToken(typ: string, payload: Record<string, unknown>, ttlMs: number): string {
  const { authSecret } = getServerEnv();
  const body = Buffer.from(
    JSON.stringify({ ...payload, typ, exp: Date.now() + ttlMs }),
    "utf8"
  ).toString("base64url");
  const sig = crypto.createHmac("sha256", authSecret).update(`${typ}.${body}`).digest("base64url");
  return `${body}.${sig}`;
}

export function verifyTypedToken<T extends Record<string, unknown>>(
  typ: string,
  token: string | undefined
): (T & { exp: number }) | null {
  if (!token) return null;
  const [body, sig] = token.split(".");
  if (!body || !sig) return null;
  const { authSecret } = getServerEnv();
  const expected = crypto.createHmac("sha256", authSecret).update(`${typ}.${body}`).digest("base64url");
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const parsed = JSON.parse(Buffer.from(body, "base64url").toString("utf8")) as T & {
      typ: string;
      exp: number;
    };
    if (parsed.typ !== typ || typeof parsed.exp !== "number" || Date.now() > parsed.exp) return null;
    return parsed;
  } catch {
    return null;
  }
}

function slugifyUsername(base: string): string {
  const cleaned = base.toLowerCase().replace(/[^a-z0-9_-]+/g, "_").replace(/^_+|_+$/g, "");
  return (cleaned.length >= 3 ? cleaned : `dev_${cleaned}`).slice(0, 24);
}

function pickFreeUsername(base: string, isTaken: (candidate: string) => boolean): string {
  const root = slugifyUsername(base);
  if (!isTaken(root)) return root;
  for (let i = 0; i < 20; i++) {
    const candidate = `${root.slice(0, 24)}_${crypto.randomBytes(2).toString("hex")}`;
    if (!isTaken(candidate)) return candidate;
  }
  return `dev_${crypto.randomBytes(6).toString("hex")}`;
}

export type PasswordlessIdentity =
  | { kind: "wallet"; address: string }
  | { kind: "email"; email: string }
  | { kind: "phone"; phone: string };

function identityDefaults(identity: PasswordlessIdentity) {
  if (identity.kind === "wallet") {
    const short = `${identity.address.slice(0, 6)}…${identity.address.slice(-4)}`;
    return { usernameBase: `w_${identity.address.slice(2, 10)}`, displayName: short };
  }
  if (identity.kind === "email") {
    const local = identity.email.split("@")[0] ?? "developer";
    return { usernameBase: local, displayName: local };
  }
  return { usernameBase: `p_${identity.phone.slice(-6)}`, displayName: `Developer ${identity.phone.slice(-4)}` };
}

/** Local mode: return the account for this identity, creating it on first sign-in. */
export function findOrCreateLocalUser(identity: PasswordlessIdentity): {
  user: StoredUser;
  created: boolean;
} {
  const db = readDb();
  const existing = db.users.find((u) =>
    identity.kind === "wallet"
      ? u.walletAddress?.toLowerCase() === identity.address.toLowerCase()
      : identity.kind === "email"
        ? u.email === identity.email
        : u.phone === identity.phone
  );
  if (existing) return { user: existing, created: false };

  const defaults = identityDefaults(identity);
  const user: StoredUser = {
    id: crypto.randomUUID(),
    email: identity.kind === "email" ? identity.email : "",
    username: pickFreeUsername(defaults.usernameBase, (c) => db.users.some((u) => u.username === c)),
    displayName: defaults.displayName,
    bio: "",
    githubUrl: "",
    websiteUrl: "",
    passwordHash: "",
    walletAddress: identity.kind === "wallet" ? identity.address : undefined,
    phone: identity.kind === "phone" ? identity.phone : undefined,
    authProvider:
      identity.kind === "wallet" ? "wallet" : identity.kind === "email" ? "email-code" : "phone",
    roles: ["developer"],
    totalPoints: 0,
    challengesCompleted: 0,
    securityMissionsCompleted: 0,
    createdAt: new Date().toISOString(),
  };
  db.users.push(user);
  writeDb(db);
  return { user, created: true };
}

/**
 * Supabase mode: make sure an auth user has a `profiles` row and the developer role.
 * Needed for OAuth, magic-link, SMS and wallet sign-ins, which create the auth user
 * without going through /auth/register.
 */
export async function ensureSupabaseProfile(
  authUser: {
    id: string;
    email?: string | null;
    phone?: string | null;
    user_metadata?: Record<string, unknown> | null;
    app_metadata?: Record<string, unknown> | null;
  },
  extra: { walletAddress?: string; provider?: string } = {}
): Promise<void> {
  const admin = getSupabaseAdminClient();
  if (!admin) throw new ConsinzoError("SUPABASE_UNAVAILABLE", "Supabase is not configured.", 500);

  const { data: existing } = await admin
    .from("profiles")
    .select("id")
    .eq("id", authUser.id)
    .maybeSingle();
  if (existing) return;

  const meta = authUser.user_metadata ?? {};
  const str = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : undefined);
  const realEmail =
    authUser.email && !authUser.email.endsWith(SYNTHETIC_EMAIL_DOMAIN) ? authUser.email : undefined;
  const usernameBase =
    str(meta.username) ??
    str(meta.user_name) ??
    str(meta.preferred_username) ??
    (extra.walletAddress ? `w_${extra.walletAddress.slice(2, 10)}` : undefined) ??
    realEmail?.split("@")[0] ??
    (authUser.phone ? `p_${authUser.phone.slice(-6)}` : "developer");
  const displayName =
    str(meta.display_name) ??
    str(meta.full_name) ??
    str(meta.name) ??
    (extra.walletAddress
      ? `${extra.walletAddress.slice(0, 6)}…${extra.walletAddress.slice(-4)}`
      : usernameBase);

  // Username is unique in the database: retry with a suffix on collision.
  let inserted = false;
  for (let attempt = 0; attempt < 6 && !inserted; attempt++) {
    const base = slugifyUsername(usernameBase);
    const username = attempt === 0 ? base : `${base}_${crypto.randomBytes(2).toString("hex")}`;
    const { error } = await admin.from("profiles").insert({
      id: authUser.id,
      username,
      display_name: displayName.slice(0, 60),
      wallet_address: extra.walletAddress ?? null,
      phone: authUser.phone || null,
      auth_provider: extra.provider ?? str(authUser.app_metadata?.provider) ?? null,
      github_url:
        str(authUser.app_metadata?.provider) === "github" && str(meta.user_name)
          ? `https://github.com/${str(meta.user_name)}`
          : null,
    });
    if (!error) inserted = true;
    else if (error.code !== "23505") {
      throw new ConsinzoError("PROFILE_CREATE_FAILED", "Could not create your profile.", 500);
    }
  }
  if (!inserted) {
    throw new ConsinzoError("PROFILE_CREATE_FAILED", "Could not create your profile.", 500);
  }

  const { data: devRole } = await admin
    .from("roles")
    .select("id")
    .eq("name", "developer")
    .maybeSingle();
  if (devRole?.id) {
    await admin.from("user_roles").insert({ user_id: authUser.id, role_id: devRole.id });
  }
}

/**
 * Supabase mode: sign a verified wallet in. Wallet accounts are Supabase auth users with a
 * non-deliverable placeholder email; the session is minted server-side through a one-time
 * magic-link token, so the browser never handles a credential for it.
 */
export async function signInSupabaseWallet(address: string): Promise<void> {
  const admin = getSupabaseAdminClient();
  const authClient = await getSupabaseServerAuthClient();
  if (!admin || !authClient) {
    throw new ConsinzoError("SUPABASE_UNAVAILABLE", "Supabase is not configured.", 500);
  }
  const email = `${address.toLowerCase()}${SYNTHETIC_EMAIL_DOMAIN}`;

  const { data: profile } = await admin
    .from("profiles")
    .select("id")
    .ilike("wallet_address", address)
    .maybeSingle();

  if (!profile) {
    const { data: created, error } = await admin.auth.admin.createUser({
      email,
      email_confirm: true,
      user_metadata: { wallet_address: address },
    });
    // "already registered" means an earlier attempt created the auth user but not the profile.
    if (error && !/already.*registered|already exists/i.test(error.message)) {
      throw new ConsinzoError("WALLET_SIGNIN_FAILED", "Could not create a wallet account.", 500);
    }
    if (created?.user) {
      await ensureSupabaseProfile(created.user, { walletAddress: address, provider: "wallet" });
    }
  }

  const { data: link, error: linkError } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email,
  });
  const tokenHash = link?.properties?.hashed_token;
  if (linkError || !tokenHash) {
    throw new ConsinzoError("WALLET_SIGNIN_FAILED", "Could not start a wallet session.", 500);
  }
  const { data: session, error: verifyError } = await authClient.auth.verifyOtp({
    token_hash: tokenHash,
    type: "magiclink",
  });
  if (verifyError || !session.user) {
    throw new ConsinzoError("WALLET_SIGNIN_FAILED", "Could not start a wallet session.", 500);
  }
  await ensureSupabaseProfile(session.user, { walletAddress: address, provider: "wallet" });
}
