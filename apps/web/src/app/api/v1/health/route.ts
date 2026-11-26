import { NextResponse } from "next/server";
import { getServerEnv } from "@/lib/env";
import { detectFoundryToolchain } from "@consinzo/runner-evm";

export async function GET() {
  const env = getServerEnv();
  const toolchain = await detectFoundryToolchain();
  return NextResponse.json({
    status: "ok",
    service: "consinzo-web",
    authMode: env.isSupabaseConfigured ? "supabase" : "local-dev-signed-cookie",
    execution: {
      localEvmRunner: env.enableLocalEvmRunner,
      localNearRunner: true,
      remoteActionsEval: env.enableRemoteActionsEval,
      nativeForgeAvailable: toolchain.forgeAvailable,
      bundledSolcVersion: "0.8.28",
      nearTypeScriptVersion: "5.9.3",
      activeEcosystems: ["ethereum-evm", "near"],
    },
    timestamp: new Date().toISOString(),
  });
}
