import crypto from "node:crypto";
import { NextResponse } from "next/server";
import { AuditFindingInputSchema } from "@consinzo/validators";
import { getSessionUser, requireSessionUser } from "@/lib/auth";
import { handleApiError } from "@/lib/http";
import { readDb, writeDb } from "@/lib/store";

export async function GET() {
  const user = await getSessionUser();
  if (!user) {
    return NextResponse.json({ reports: [] });
  }
  const db = readDb();
  const isReviewer = user.roles.some((r) =>
    ["security_reviewer", "platform_admin", "super_admin"].includes(r)
  );
  const reports = isReviewer
    ? db.auditReports
    : db.auditReports.filter((r) => r.authorId === user.id);
  return NextResponse.json({ reports });
}

export async function POST(req: Request) {
  try {
    const user = await requireSessionUser();
    const body = AuditFindingInputSchema.parse(await req.json());
    const db = readDb();
    const report = {
      id: crypto.randomUUID(),
      missionSlug: body.missionSlug,
      authorId: user.id,
      authorUsername: user.username,
      title: body.title,
      severity: body.severity,
      affectedComponent: body.affectedComponent,
      rootCause: body.rootCause,
      attackScenario: body.attackScenario,
      impact: body.impact,
      proofOfConcept: body.proofOfConcept,
      recommendedRemediation: body.recommendedRemediation,
      status: "submitted" as const,
      createdAt: new Date().toISOString(),
    };
    db.auditReports.unshift(report);
    writeDb(db);
    return NextResponse.json({ report }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
