import { NextResponse } from "next/server";
import { ensureSupabaseProfile } from "@/lib/auth";
import { getRequestOrigin, safeNextPath } from "@/lib/auth-methods";
import { getSupabaseServerAuthClient } from "@/lib/supabase";

/**
 * Landing route for Google/GitHub (PKCE `code`) and for email links (`token_hash`).
 * Exchanges the one-time value for a session cookie, makes sure a profile exists, then
 * sends the user on to a same-site path.
 */
export async function GET(req: Request) {
  const url = new URL(req.url);
  const { origin } = getRequestOrigin(req);
  const next = safeNextPath(url.searchParams.get("next"));
  const fail = (code: string) =>
    NextResponse.redirect(`${origin}/auth?error=${code}&next=${encodeURIComponent(next)}`);

  const authClient = await getSupabaseServerAuthClient();
  if (!authClient) return fail("provider_unavailable");
  if (url.searchParams.get("error")) return fail("access_denied");

  const code = url.searchParams.get("code");
  const tokenHash = url.searchParams.get("token_hash");
  const type = url.searchParams.get("type");

  let user = null;
  if (code) {
    const { data, error } = await authClient.auth.exchangeCodeForSession(code);
    if (error) return fail("callback_failed");
    user = data.user;
  } else if (tokenHash && (type === "email" || type === "magiclink" || type === "signup")) {
    const { data, error } = await authClient.auth.verifyOtp({ token_hash: tokenHash, type });
    if (error) return fail("link_expired");
    user = data.user;
  }
  if (!user) return fail("callback_failed");

  try {
    await ensureSupabaseProfile(user);
  } catch {
    return fail("profile_failed");
  }
  return NextResponse.redirect(`${origin}${next}`);
}
