import { NextResponse } from "next/server";
import { SESSION_COOKIE_NAME } from "@/lib/auth";
import { getServerEnv } from "@/lib/env";
import { getSupabaseServerAuthClient } from "@/lib/supabase";

export async function POST() {
  const env = getServerEnv();
  if (env.isSupabaseConfigured) {
    const supabaseAuth = await getSupabaseServerAuthClient();
    await supabaseAuth?.auth.signOut();
  }

  const res = NextResponse.json({ ok: true });
  res.cookies.set(SESSION_COOKIE_NAME, "", {
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: 0,
  });
  return res;
}
