import { ConsinzoError } from "@consinzo/shared";

/**
 * Small fixed-window limiter kept in process memory. It is a first line of defence for
 * unauthenticated endpoints (guest runs, contact form, sign-in codes). On serverless each
 * instance has its own window, so pair it with an edge/WAF limit for hard guarantees.
 */
const buckets = new Map<string, { count: number; resetAt: number }>();

export function getClientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for");
  return forwarded?.split(",")[0]?.trim() || req.headers.get("x-real-ip") || "local";
}

export function checkRateLimit(
  key: string,
  limit: number,
  windowMs: number
): { allowed: boolean; remaining: number; resetAt: number } {
  const now = Date.now();
  if (buckets.size > 5000) {
    for (const [k, b] of buckets) if (b.resetAt <= now) buckets.delete(k);
  }
  let bucket = buckets.get(key);
  if (!bucket || bucket.resetAt <= now) {
    bucket = { count: 0, resetAt: now + windowMs };
    buckets.set(key, bucket);
  }
  if (bucket.count >= limit) return { allowed: false, remaining: 0, resetAt: bucket.resetAt };
  bucket.count += 1;
  return { allowed: true, remaining: limit - bucket.count, resetAt: bucket.resetAt };
}

export function enforceRateLimit(key: string, limit: number, windowMs: number, what: string) {
  const result = checkRateLimit(key, limit, windowMs);
  if (!result.allowed) {
    const minutes = Math.max(1, Math.ceil((result.resetAt - Date.now()) / 60_000));
    throw new ConsinzoError(
      "RATE_LIMITED",
      `Too many ${what}. Try again in about ${minutes} minute${minutes === 1 ? "" : "s"}.`,
      429,
      { retryAfterSeconds: Math.ceil((result.resetAt - Date.now()) / 1000) }
    );
  }
  return result;
}
