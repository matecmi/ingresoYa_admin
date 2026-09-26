import { createHash } from "node:crypto";

import { logger } from "firebase-functions";

type SafeLogFields = Readonly<Record<string, number | boolean>>;

/** Do not log request payloads, answers, explanations or raw UIDs. */
export function safeLog(event: string, uid: string, fields: SafeLogFields = {}): void {
  logger.info(event, {
    actor: createHash("sha256").update(uid).digest("hex").slice(0, 12),
    ...fields
  });
}

export function safeError(
  event: string,
  error: unknown,
  fields: SafeLogFields = {}
): void {
  logger.error(event, {
    category: error instanceof Error ? error.name : "unknown",
    ...fields
  });
}
