import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { getServerEnv } from "./env";

let cachedAdminClient: SupabaseClient | null = null;

/**
 * SERVER-ONLY: Returns a Supabase client using SUPABASE_SERVICE_ROLE_KEY.
 * Never import this file from client components.
 */
export function getSupabaseAdminClient(): SupabaseClient | null {
  const env = getServerEnv();
  if (!env.isSupabaseConfigured) return null;
  if (!cachedAdminClient) {
    cachedAdminClient = createClient(env.supabaseUrl, env.supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });
  }
  return cachedAdminClient;
}

export async function getSupabaseServerAuthClient() {
  const env = getServerEnv();
  if (!env.isSupabaseConfigured) return null;
  const cookieStore = await cookies();
  return createServerClient(env.supabaseUrl, env.supabaseAnonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(
        cookiesToSet: Array<{ name: string; value: string; options?: Record<string, unknown> }>
      ) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Server Components cannot mutate cookies during render; route handlers handle writes.
        }
      },
    },
  });
}
