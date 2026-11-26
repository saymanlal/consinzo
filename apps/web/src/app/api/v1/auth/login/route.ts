import { NextResponse } from "next/server";
import { z } from "zod";
import { ConsinzoError } from "@consinzo/shared";
import {
  SESSION_COOKIE_NAME,
  signSessionToken,
  toSessionUser,
  verifyPassword,
} from "@/lib/auth";
import { handleApiError } from "@/lib/http";
import { readDb } from "@/lib/store";

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export async function POST(req: Request) {
  try {
    const body = LoginSchema.parse(await req.json());
    const db = readDb();
    const user = db.users.find((u) => u.email === body.email.trim().toLowerCase());
    if (!user || !verifyPassword(body.password, user.passwordHash)) {
      throw new ConsinzoError("INVALID_CREDENTIALS", "Invalid email or password.", 401);
    }

    const token = signSessionToken({
      userId: user.id,
      exp: Date.now() + 7 * 24 * 60 * 60 * 1000,
    });

    const res = NextResponse.json({ user: toSessionUser(user) });
    res.cookies.set(SESSION_COOKIE_NAME, token, {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      path: "/",
      maxAge: 7 * 24 * 60 * 60,
    });
    return res;
  } catch (err) {
    return handleApiError(err);
  }
}
