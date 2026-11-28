import { NextResponse } from "next/server";
import { z } from "zod";
import { ConsinzoError } from "@consinzo/shared";
import { getAuthMethodAvailability, getRequestOrigin, safeNextPath } from "@/lib/auth-methods";
import { handleApiError } from "@/lib/http";
import { createLocalOtp, OtpTargetSchema } from "@/lib/otp";
import { enforceRateLimit, getClientIp } from "@/lib/rate-limit";
import { getSupabaseServerAuthClient } from "@/lib/supabase";

const StartSchema = z.object({ next: z.string().max(300).optional() }).passthrough();

/** Sends a one-time sign-in code by email or SMS. Creates the account on first use. */
export async function POST(req: Request) {
  try {
    const raw = await req.json();
    const target = OtpTargetSchema.parse(raw);
    const { next } = StartSchema.parse(raw);
    const methods = getAuthMethodAvailability();
    if (!(target.channel === "email" ? methods.emailCode : methods.phone)) {
      throw new ConsinzoError(
        "AUTH_METHOD_UNAVAILABLE",
        target.channel === "email"
          ? "Email codes are not enabled on this deployment."
          : "Phone sign-in is not enabled on this deployment.",
        404
      );
    }

    enforceRateLimit(`otp-start-ip:${getClientIp(req)}`, 10, 15 * 60 * 1000, "code requests");
    enforceRateLimit(`otp-start:${target.identifier}`, 3, 15 * 60 * 1000, "code requests");

    if (methods.mode === "supabase") {
      const authClient = await getSupabaseServerAuthClient();
      if (!authClient) throw new ConsinzoError("SUPABASE_UNAVAILABLE", "Auth unavailable.", 500);
      const { origin } = getRequestOrigin(req);
      const { error } =
        target.channel === "email"
          ? await authClient.auth.signInWithOtp({
              email: target.identifier,
              options: {
                shouldCreateUser: true,
                emailRedirectTo: `${origin}/auth/callback?next=${encodeURIComponent(safeNextPath(next))}`,
              },
            })
          : await authClient.auth.signInWithOtp({
              phone: target.identifier,
              options: { shouldCreateUser: true },
            });
      if (error) {
        console.error("[consinzo-otp] provider refused to send a code:", error.message);
        throw new ConsinzoError(
          "CODE_NOT_SENT",
          "We could not send a code to that address. Check it and try again.",
          400
        );
      }
      return NextResponse.json({ sent: true });
    }

    // Local development only (getAuthMethodAvailability() is false in production without
    // Supabase): there is no mail or SMS provider, so the code is shown on the page.
    const code = createLocalOtp(target);
    console.info(`[consinzo-dev-otp] ${target.channel} ${target.identifier} -> ${code}`);
    return NextResponse.json({ sent: true, devCode: code });
  } catch (err) {
    return handleApiError(err);
  }
}
