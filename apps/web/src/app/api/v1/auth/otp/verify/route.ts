import { NextResponse } from "next/server";
import { z } from "zod";
import { ConsinzoError } from "@consinzo/shared";
import {
  ensureSupabaseProfile,
  findOrCreateLocalUser,
  setLocalSessionCookie,
  toSessionUser,
} from "@/lib/auth";
import { getAuthMethodAvailability } from "@/lib/auth-methods";
import { handleApiError } from "@/lib/http";
import { consumeLocalOtp, OtpTargetSchema } from "@/lib/otp";
import { enforceRateLimit, getClientIp } from "@/lib/rate-limit";
import { getSupabaseServerAuthClient } from "@/lib/supabase";

const CodeSchema = z.object({ code: z.string().trim().regex(/^\d{6}$/, "Enter the 6-digit code") });

export async function POST(req: Request) {
  try {
    const raw = await req.json();
    const target = OtpTargetSchema.parse(raw);
    const { code } = CodeSchema.parse(raw);
    const methods = getAuthMethodAvailability();
    if (!(target.channel === "email" ? methods.emailCode : methods.phone)) {
      throw new ConsinzoError("AUTH_METHOD_UNAVAILABLE", "This sign-in method is not enabled.", 404);
    }
    enforceRateLimit(`otp-verify-ip:${getClientIp(req)}`, 30, 15 * 60 * 1000, "attempts");
    enforceRateLimit(`otp-verify:${target.identifier}`, 8, 15 * 60 * 1000, "attempts");

    if (methods.mode === "supabase") {
      const authClient = await getSupabaseServerAuthClient();
      if (!authClient) throw new ConsinzoError("SUPABASE_UNAVAILABLE", "Auth unavailable.", 500);
      const { data, error } =
        target.channel === "email"
          ? await authClient.auth.verifyOtp({ email: target.identifier, token: code, type: "email" })
          : await authClient.auth.verifyOtp({ phone: target.identifier, token: code, type: "sms" });
      if (error || !data.user) {
        throw new ConsinzoError("INVALID_CODE", "That code is not correct or has expired.", 401);
      }
      await ensureSupabaseProfile(data.user, {
        provider: target.channel === "email" ? "email-code" : "phone",
      });
      return NextResponse.json({ ok: true });
    }

    consumeLocalOtp(target, code);
    const { user, created } = findOrCreateLocalUser(
      target.channel === "email"
        ? { kind: "email", email: target.identifier }
        : { kind: "phone", phone: target.identifier }
    );
    const res = NextResponse.json({ user: toSessionUser(user), created }, { status: created ? 201 : 200 });
    setLocalSessionCookie(res, user.id);
    return res;
  } catch (err) {
    return handleApiError(err);
  }
}
