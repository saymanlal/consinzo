import crypto from "node:crypto";
import { cookies } from "next/headers";
import type { RoleName } from "@consinzo/shared";
import { ConsinzoError } from "@consinzo/shared";
import { getServerEnv } from "./env";
import { readDb, writeDb, type StoredUser } from "./store";

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

  // First registered local account in dev gets platform_admin only if explicitly marked; standard users get "developer"
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
