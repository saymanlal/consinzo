import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { getAddress, verifyMessage } from "viem";
import { parseSiweMessage } from "viem/siwe";
import { z } from "zod";
import { ConsinzoError } from "@consinzo/shared";
import {
  findOrCreateLocalUser,
  setLocalSessionCookie,
  signInSupabaseWallet,
  toSessionUser,
  verifyTypedToken,
} from "@/lib/auth";
import { getRequestOrigin } from "@/lib/auth-methods";
import { getServerEnv } from "@/lib/env";
import { handleApiError } from "@/lib/http";
import { enforceRateLimit, getClientIp } from "@/lib/rate-limit";

const NONCE_COOKIE = "consinzo_wallet_nonce";

const VerifySchema = z.object({
  message: z.string().min(40).max(2000),
  signature: z.string().regex(/^0x[0-9a-fA-F]{130}$/, "Expected a 65-byte signature"),
});

const invalid = () =>
  new ConsinzoError(
    "WALLET_SIGNATURE_INVALID",
    "The wallet signature could not be verified. Request a new sign-in message and try again.",
    401
  );

/**
 * Step 2 of wallet sign-in. The signed message must be the exact one this server issued:
 * same nonce (from the HTTP-only cookie), same address, same domain, not expired. Only the
 * public address is ever stored.
 */
export async function POST(req: Request) {
  try {
    enforceRateLimit(`wallet-verify:${getClientIp(req)}`, 20, 10 * 60 * 1000, "sign-in attempts");
    const body = VerifySchema.parse(await req.json());

    const cookieStore = await cookies();
    const issued = verifyTypedToken<{ nonce: string; address: string }>(
      "wallet-nonce",
      cookieStore.get(NONCE_COOKIE)?.value
    );
    if (!issued) {
      throw new ConsinzoError(
        "WALLET_NONCE_EXPIRED",
        "The sign-in request expired. Start again.",
        401
      );
    }

    const parsed = parseSiweMessage(body.message);
    const { host } = getRequestOrigin(req);
    if (
      !parsed.address ||
      !parsed.nonce ||
      parsed.nonce !== issued.nonce ||
      getAddress(parsed.address) !== issued.address ||
      parsed.domain !== host ||
      (parsed.expirationTime && parsed.expirationTime.getTime() < Date.now())
    ) {
      throw invalid();
    }

    const ok = await verifyMessage({
      address: issued.address as `0x${string}`,
      message: body.message,
      signature: body.signature as `0x${string}`,
    }).catch(() => false);
    if (!ok) throw invalid();

    const clearNonce = (res: NextResponse) =>
      res.cookies.set(NONCE_COOKIE, "", { path: "/api/v1/auth/wallet", maxAge: 0 });

    if (getServerEnv().isSupabaseConfigured) {
      await signInSupabaseWallet(issued.address);
      const res = NextResponse.json({ ok: true, walletAddress: issued.address });
      clearNonce(res);
      return res;
    }

    const { user, created } = findOrCreateLocalUser({ kind: "wallet", address: issued.address });
    const res = NextResponse.json(
      { user: toSessionUser(user), walletAddress: issued.address, created },
      { status: created ? 201 : 200 }
    );
    setLocalSessionCookie(res, user.id);
    clearNonce(res);
    return res;
  } catch (err) {
    return handleApiError(err);
  }
}
