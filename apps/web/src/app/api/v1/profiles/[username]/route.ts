import { NextResponse } from "next/server";
import { getPublicDeveloperPortfolio } from "@/lib/data-adapter";

export async function GET(
  _req: Request,
  context: { params: Promise<{ username: string }> }
) {
  const { username } = await context.params;
  const portfolio = await getPublicDeveloperPortfolio(username);
  if (!portfolio) {
    return NextResponse.json(
      { error: { code: "NOT_FOUND", message: "Developer profile not found." } },
      { status: 404 }
    );
  }
  return NextResponse.json({ portfolio });
}
