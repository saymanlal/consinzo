import { NextResponse } from "next/server";
import { z } from "zod";
import {
  createUserAccount,
  SESSION_COOKIE_NAME,
  signSessionToken,
  toSessionUser,
} from "@/lib/auth";
import { handleApiError } from "@/lib/http";

const RegisterSchema = z.object({
  email: z.string().email(),
  username: z.string().regex(/^[a-zA-Z0-9_-]{3,32}$/, "Username must be 3-32 alphanumeric characters"),
  displayName: z.string().min(2).max(60),
  password: z.string().min(8).max(128),
});

export async function POST(req: Request) {
  try {
    const body = RegisterSchema.parse(await req.json());
    const user = createUserAccount(body);
    const token = signSessionToken({
      userId: user.id,
      exp: Date.now() + 7 * 24 * 60 * 60 * 1000,
    });

    const res = NextResponse.json({ user: toSessionUser(user) }, { status: 201 });
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
