import { NextResponse } from "next/server";
import { z } from "zod";
import {
  createUserAccount,
  registerSupabaseAccount,
  setLocalSessionCookie,
  toSessionUser,
} from "@/lib/auth";
import { getServerEnv } from "@/lib/env";
import { handleApiError } from "@/lib/http";
import { enforceRateLimit, getClientIp } from "@/lib/rate-limit";

const RegisterSchema = z.object({
  email: z.string().email(),
  username: z.string().regex(/^[a-zA-Z0-9_-]{3,32}$/, "Username must be 3-32 alphanumeric characters"),
  displayName: z.string().min(2).max(60),
  password: z.string().min(8).max(128),
});

export async function POST(req: Request) {
  try {
    enforceRateLimit(`register:${getClientIp(req)}`, 10, 60 * 60 * 1000, "sign-up attempts");
    const body = RegisterSchema.parse(await req.json());
    const env = getServerEnv();

    if (env.isSupabaseConfigured) {
      const user = await registerSupabaseAccount(body);
      return NextResponse.json({ user }, { status: 201 });
    }

    const user = createUserAccount(body);
    const res = NextResponse.json({ user: toSessionUser(user) }, { status: 201 });
    setLocalSessionCookie(res, user.id);
    return res;
  } catch (err) {
    return handleApiError(err);
  }
}
