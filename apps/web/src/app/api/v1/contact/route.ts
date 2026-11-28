import crypto from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getServerEnv } from "@/lib/env";
import { handleApiError } from "@/lib/http";
import { enforceRateLimit, getClientIp } from "@/lib/rate-limit";
import { readDb, writeDb } from "@/lib/store";
import { getSupabaseAdminClient } from "@/lib/supabase";

const ContactSchema = z.object({
  name: z.string().trim().min(2).max(80),
  email: z.string().trim().email().max(160),
  topic: z.enum(["general", "support", "partnership", "security", "press"]),
  message: z.string().trim().min(10).max(4000),
  // Honeypot: real visitors never see or fill this field.
  company: z.string().max(0).optional(),
});

export async function POST(req: Request) {
  try {
    enforceRateLimit(`contact:${getClientIp(req)}`, 5, 60 * 60 * 1000, "messages");
    const raw = (await req.json()) as Record<string, unknown>;
    if (typeof raw.company === "string" && raw.company.length > 0) {
      // Pretend success so bots get no signal.
      return NextResponse.json({ ok: true }, { status: 201 });
    }
    const body = ContactSchema.parse(raw);
    const record = {
      id: crypto.randomUUID(),
      name: body.name,
      email: body.email.toLowerCase(),
      topic: body.topic,
      message: body.message,
      createdAt: new Date().toISOString(),
    };

    const admin = getServerEnv().isSupabaseConfigured ? getSupabaseAdminClient() : null;
    if (admin) {
      const { error } = await admin.from("contact_messages").insert({
        id: record.id,
        name: record.name,
        email: record.email,
        topic: record.topic,
        message: record.message,
      });
      if (error) throw new Error(`contact_messages insert failed: ${error.message}`);
    } else {
      const db = readDb();
      db.contactMessages = [...(db.contactMessages ?? []), record].slice(-500);
      writeDb(db);
    }
    return NextResponse.json({ ok: true }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
