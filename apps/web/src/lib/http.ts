import { NextResponse } from "next/server";
import { ZodError } from "zod";
import { ConsinzoError } from "@consinzo/shared";

export function handleApiError(err: unknown) {
  if (err instanceof ConsinzoError) {
    return NextResponse.json(err.toApiResponse(), { status: err.status });
  }
  if (err instanceof ZodError) {
    return NextResponse.json(
      {
        error: {
          code: "VALIDATION_ERROR",
          message: "Invalid request payload.",
          details: err.flatten(),
        },
      },
      { status: 400 }
    );
  }
  console.error("[consinzo-api-error]", err);
  return NextResponse.json(
    {
      error: {
        code: "INTERNAL_ERROR",
        message: "An unexpected internal error occurred.",
      },
    },
    { status: 500 }
  );
}
