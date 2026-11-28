import { NextResponse } from "next/server";
import { getAddress, isAddress } from "viem";
import { createSiweMessage, generateSiweNonce } from "viem/siwe";
import { ConsinzoError } from "@consinzo/shared";
import { signTypedToken } from "@/lib/auth";
import { getRequestOrigin } from "@/lib/auth-methods";
import { handleApiError } from "@/lib/http";
import { enforceRateLimit, getClientIp } from "@/lib/rate-limit";

const WALLET_NONCE_COOKIE = "consinzo_wallet_nonce";
const NONCE_TTL_MS = 10 * 60 * 1000;

/** Step 1 of wallet sign-in: issue a one-time Sign-In with Ethereum (EIP-4361) message. */
export async function GET(req: Request) {
  try {
    enforceRateLimit(`wallet-nonce:${getClientIp(req)}`, 30, 10 * 60 * 1000, "sign-in attempts");
    const raw = new URL(req.url).searchParams.get("address") ?? "";
    if (!isAddress(raw)) {
      throw new ConsinzoError("INVALID_ADDRESS", "That is not a valid wallet address.", 400);
    }
    const address = getAddress(raw);
    const { origin, host } = getRequestOrigin(req);
    const nonce = generateSiweNonce();
    const now = new Date();

    const message = createSiweMessage({
      domain: host,
      address,
      statement:
        "Sign in to CONSINZO. This proves you control this wallet. It is not a transaction and costs no gas.",
      uri: origin,
      version: "1",
      chainId: 1,
      nonce,
      issuedAt: now,
      expirationTime: new Date(now.getTime() + NONCE_TTL_MS),
    });

    const res = NextResponse.json({ message });
    res.cookies.set(WALLET_NONCE_COOKIE, signTypedToken("wallet-nonce", { nonce, address }, NONCE_TTL_MS), {
      httpOnly: true,
      sameSite: "strict",
      secure: process.env.NODE_ENV === "production",
      path: "/api/v1/auth/wallet",
      maxAge: NONCE_TTL_MS / 1000,
    });
    return res;
  } catch (err) {
    return handleApiError(err);
  }
}
