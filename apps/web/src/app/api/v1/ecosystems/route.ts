import { NextResponse } from "next/server";
import { ECOSYSTEM_REGISTRY, SUPPORT_LEVEL_LABELS } from "@consinzo/ecosystem-registry";

export async function GET() {
  return NextResponse.json({
    ecosystems: ECOSYSTEM_REGISTRY,
    supportLevels: SUPPORT_LEVEL_LABELS,
  });
}
