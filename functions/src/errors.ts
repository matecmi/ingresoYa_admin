import { HttpsError } from "firebase-functions/v2/https";

type ErrorCode =
  | "invalid-argument"
  | "unauthenticated"
  | "permission-denied"
  | "not-found"
  | "already-exists"
  | "failed-precondition"
  | "resource-exhausted"
  | "internal";

export class ExamBackendError extends Error {
  public constructor(
    public readonly code: ErrorCode,
    public readonly safeMessage: string,
    public readonly details?: Record<string, unknown>
  ) {
    super(safeMessage);
    this.name = "ExamBackendError";
  }
}

export const invalidArgument = (message: string): ExamBackendError =>
  new ExamBackendError("invalid-argument", message);

export const unauthenticated = (): ExamBackendError =>
  new ExamBackendError("unauthenticated", "Authentication is required.");

export const workflowNotReady = (): ExamBackendError =>
  new ExamBackendError(
    "failed-precondition",
    "The exam workflow is not enabled yet."
  );

export const failedPrecondition = (
  message: string,
  details?: Record<string, unknown>
): ExamBackendError => new ExamBackendError("failed-precondition", message, details);

export const notFound = (message: string, reason: string): ExamBackendError =>
  new ExamBackendError("not-found", message, { reason });

export const resourceExhausted = (
  message: string,
  details?: Record<string, unknown>
): ExamBackendError => new ExamBackendError("resource-exhausted", message, details);

export function asHttpsError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  if (error instanceof ExamBackendError) {
    return new HttpsError(error.code, error.safeMessage, {
      reason: defaultReason(error),
      ...error.details
    });
  }
  return new HttpsError("internal", "The exam service could not complete the request.", {
    reason: "unexpected_server_error"
  });
}

/** Every callable error has a stable, non-sensitive reason for client mapping. */
export function defaultReason(error: ExamBackendError): string {
  if (typeof error.details?.reason === "string") return error.details.reason;
  switch (error.code) {
    case "invalid-argument": return "invalid_request";
    case "unauthenticated": return "authentication_required";
    case "resource-exhausted": return "resource_limit";
    case "failed-precondition": return "precondition_failed";
    case "not-found": return "resource_not_found";
    default: return "server_error";
  }
}
