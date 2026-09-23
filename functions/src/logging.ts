import { createHash } from "node:crypto";

import { logger } from "firebase-functions";

/** Do not log request payloads, answers, explanations or raw UIDs. */
export function safeLog(event: string, uid: string): void {
  logger.info(event, {
    actor: createHash("sha256").update(uid).digest("hex").slice(0, 12)
  });
}

export function safeError(event: string, error: unknown): void {
  logger.error(event, {
    category: error instanceof Error ? error.name : "unknown"
  });
}
