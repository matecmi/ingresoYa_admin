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
    public readonly safeMessage: string
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

export function asHttpsError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  if (error instanceof ExamBackendError) {
    return new HttpsError(error.code, error.safeMessage);
  }
  return new HttpsError("internal", "The exam service could not complete the request.");
}
