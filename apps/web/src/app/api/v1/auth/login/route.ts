import { NextResponse } from "next/server";
import { z } from "zod";
import { ConsinzoError } from "@consinzo/shared";
import {
  setLocalSessionCookie,
  toSessionUser,
  verifyPassword,
} from "@/lib/auth";
import { getUserProfileById } from "@/lib/data-adapter";
import { getServerEnv } from "@/lib/env";
import { handleApiError } from "@/lib/http";
import { enforceRateLimit, getClientIp } from "@/lib/rate-limit";
import { readDb } from "@/lib/store";
import { getSupabaseServerAuthClient } from "@/lib/supabase";

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export async function POST(req: Request) {
  try {
    enforceRateLimit(`login:${getClientIp(req)}`, 20, 15 * 60 * 1000, "sign-in attempts");
    const body = LoginSchema.parse(await req.json());
    const env = getServerEnv();

    if (env.isSupabaseConfigured) {
      const supabaseAuth = await getSupabaseServerAuthClient();
      if (!supabaseAuth) {
        throw new ConsinzoError("SUPABASE_UNAVAILABLE", "Auth client unavailable.", 500);
      }
      const { data, error } = await supabaseAuth.auth.signInWithPassword({
        email: body.email.trim().toLowerCase(),
        password: body.password,
      });
      if (error || !data.user) {
        throw new ConsinzoError("INVALID_CREDENTIALS", "Invalid email or password.", 401);
      }
      const profile = await getUserProfileById(data.user.id);
      return NextResponse.json({
        user: profile ?? {
          id: data.user.id,
          email: data.user.email ?? "",
          username: data.user.user_metadata?.username ?? "developer",
          displayName: data.user.user_metadata?.display_name ?? "Developer",
          roles: ["developer"],
        },
      });
    }

    const db = readDb();
    const user = db.users.find((u) => u.email === body.email.trim().toLowerCase());
    // Accounts created by wallet, email code or phone have no password to check.
    if (!user || !user.passwordHash || !verifyPassword(body.password, user.passwordHash)) {
      throw new ConsinzoError("INVALID_CREDENTIALS", "Invalid email or password.", 401);
    }

    const res = NextResponse.json({ user: toSessionUser(user) });
    setLocalSessionCookie(res, user.id);
    return res;
  } catch (err) {
    return handleApiError(err);
  }
}
