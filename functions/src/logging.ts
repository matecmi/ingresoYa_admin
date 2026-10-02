import { createHash } from "node:crypto";

import { logger } from "firebase-functions";
import { HttpsError } from "firebase-functions/v2/https";

import type { DeploymentEnvironment } from "./config";
import { defaultReason, ExamBackendError } from "./errors";

type SafeLogFields = Readonly<Record<string, number | boolean>>;
type ErrorContext = Readonly<{ environment: DeploymentEnvironment; uid?: string }>;

function actorHash(uid: string): string {
  return createHash("sha256").update(uid).digest("hex").slice(0, 12);
}

/** Do not log request payloads, answers, explanations or raw UIDs. */
export function safeLog(event: string, uid: string, fields: SafeLogFields = {}): void {
  logger.info(event, {
    actor: actorHash(uid),
    ...fields
  });
}

/** No request payload, raw user ID, answer, template ID or error message is logged. */
export function errorDiagnostic(error: unknown, context: ErrorContext): Record<string, string> {
  const code = error instanceof ExamBackendError || error instanceof HttpsError
    ? error.code
    : "internal";
  const rawReason = error instanceof ExamBackendError
    ? defaultReason(error)
    : error instanceof HttpsError && error.details !== null && typeof error.details === "object"
      ? (error.details as Record<string, unknown>).reason
      : undefined;
  const reason = typeof rawReason === "string" && /^[a-z][a-z0-9_]{0,63}$/.test(rawReason)
    ? rawReason
    : "unexpected_server_error";
  return {
    environment: context.environment,
    category: error instanceof Error ? error.name : "unknown",
    errorCode: code,
    reason,
    ...(context.uid === undefined ? {} : { actor: actorHash(context.uid) })
  };
}

export function safeError(
  event: string,
  error: unknown,
  fields: SafeLogFields,
  context: ErrorContext
): void {
  logger.error(event, {
    ...errorDiagnostic(error, context),
    ...fields
  });
}
