import crypto from "node:crypto";
import { NextResponse } from "next/server";
import { AuditFindingInputSchema } from "@consinzo/validators";
import { getSessionUser, requireSessionUser } from "@/lib/auth";
import { createAuditReport, listAuditReportsForActor } from "@/lib/data-adapter";
import { handleApiError } from "@/lib/http";

export async function GET() {
  const user = await getSessionUser();
  if (!user) {
    return NextResponse.json({ reports: [] });
  }
  const isReviewer = user.roles.some((r) =>
    ["security_reviewer", "platform_admin", "super_admin"].includes(r)
  );
  const reports = await listAuditReportsForActor(user.id, isReviewer);
  return NextResponse.json({ reports });
}

export async function POST(req: Request) {
  try {
    const user = await requireSessionUser();
    const body = AuditFindingInputSchema.parse(await req.json());
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
    await createAuditReport(report);
    return NextResponse.json({ report }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
