import crypto from "node:crypto";
import { z } from "zod";
import { ConsinzoError } from "@consinzo/shared";
import { getServerEnv } from "./env";
import { readDb, writeDb } from "./store";

export const OtpTargetSchema = z.discriminatedUnion("channel", [
  z.object({
    channel: z.literal("email"),
    identifier: z.string().trim().toLowerCase().email().max(160),
  }),
  z.object({
    channel: z.literal("phone"),
    identifier: z
      .string()
      .trim()
      .transform((v) => v.replace(/[\s()-]/g, ""))
      .pipe(
        z
          .string()
          .regex(/^\+[1-9]\d{7,14}$/, "Use international format, for example +14155552671")
      ),
  }),
]);

export type OtpTarget = z.infer<typeof OtpTargetSchema>;

const TTL_MS = 10 * 60 * 1000;
const MAX_ATTEMPTS = 5;

function hashCode(target: OtpTarget, code: string): string {
  return crypto
    .createHmac("sha256", getServerEnv().authSecret)
    .update(`otp:${target.channel}:${target.identifier}:${code}`)
    .digest("hex");
}

/** Local-mode only: create a 6-digit code. The caller decides how it reaches the user. */
export function createLocalOtp(target: OtpTarget): string {
  const code = crypto.randomInt(0, 1_000_000).toString().padStart(6, "0");
  const db = readDb();
  const now = Date.now();
  db.otpChallenges = [
    ...(db.otpChallenges ?? []).filter(
      (c) =>
        c.expiresAt > now &&
        !(c.channel === target.channel && c.identifier === target.identifier)
    ),
    {
      channel: target.channel,
      identifier: target.identifier,
      codeHash: hashCode(target, code),
      expiresAt: now + TTL_MS,
      attempts: 0,
    },
  ];
  writeDb(db);
  return code;
}

/** Local-mode only: check a code. Single use, expires, and locks after five wrong tries. */
export function consumeLocalOtp(target: OtpTarget, code: string): void {
  const db = readDb();
  const challenges = db.otpChallenges ?? [];
  const challenge = challenges.find(
    (c) => c.channel === target.channel && c.identifier === target.identifier
  );
  const fail = (message: string) => new ConsinzoError("INVALID_CODE", message, 401);

  if (!challenge || challenge.expiresAt < Date.now()) {
    throw fail("That code has expired. Request a new one.");
  }
  if (challenge.attempts >= MAX_ATTEMPTS) {
    db.otpChallenges = challenges.filter((c) => c !== challenge);
    writeDb(db);
    throw fail("Too many wrong attempts. Request a new code.");
  }
  const expected = Buffer.from(challenge.codeHash, "hex");
  const actual = Buffer.from(hashCode(target, code), "hex");
  if (expected.length !== actual.length || !crypto.timingSafeEqual(expected, actual)) {
    challenge.attempts += 1;
    writeDb(db);
    throw fail("That code is not correct.");
  }
  db.otpChallenges = challenges.filter((c) => c !== challenge);
  writeDb(db);
}
