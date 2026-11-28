import { NextResponse } from "next/server";
import { getAuthMethodAvailability } from "@/lib/auth-methods";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json({ methods: getAuthMethodAvailability() });
}
