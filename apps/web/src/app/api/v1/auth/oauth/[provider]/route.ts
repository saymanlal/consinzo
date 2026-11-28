import { NextResponse } from "next/server";
import { getAuthMethodAvailability, getRequestOrigin, safeNextPath } from "@/lib/auth-methods";
import { getSupabaseServerAuthClient } from "@/lib/supabase";

const PROVIDERS = ["google", "github"] as const;
type Provider = (typeof PROVIDERS)[number];

/** Starts Google or GitHub sign-in (Supabase OAuth with PKCE) and redirects to the provider. */
export async function GET(req: Request, ctx: { params: Promise<{ provider: string }> }) {
  const { provider } = await ctx.params;
  const { origin } = getRequestOrigin(req);
  const next = safeNextPath(new URL(req.url).searchParams.get("next"));
  const fail = (code: string) =>
    NextResponse.redirect(`${origin}/auth?error=${code}&next=${encodeURIComponent(next)}`);

  if (!(PROVIDERS as readonly string[]).includes(provider)) return fail("unknown_provider");
  const methods = getAuthMethodAvailability();
  if (!methods[provider as Provider]) return fail("provider_unavailable");

  const authClient = await getSupabaseServerAuthClient();
  if (!authClient) return fail("provider_unavailable");

  const { data, error } = await authClient.auth.signInWithOAuth({
    provider: provider as Provider,
    options: {
      redirectTo: `${origin}/auth/callback?next=${encodeURIComponent(next)}`,
      skipBrowserRedirect: true,
    },
  });
  if (error || !data.url) return fail("oauth_start_failed");
  return NextResponse.redirect(data.url);
}
