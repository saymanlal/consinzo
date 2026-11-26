import type { ApiErrorShape } from "./types";

export class ConsinzoError extends Error {
  public readonly code: string;
  public readonly status: number;
  public readonly details?: unknown;

  constructor(code: string, message: string, status = 400, details?: unknown) {
    super(message);
    this.name = "ConsinzoError";
    this.code = code;
    this.status = status;
    this.details = details;
  }

  toApiResponse(requestId?: string): ApiErrorShape {
    return {
      error: {
        code: this.code,
        message: this.message,
        details: this.details,
        requestId,
      },
    };
  }
}
