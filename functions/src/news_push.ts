import { Timestamp } from "firebase-admin/firestore";
import { getMessaging, type Message } from "firebase-admin/messaging";

import { db } from "./admin";
import type { BackendConfig, DeploymentEnvironment } from "./config";
import { safeError, safeLog } from "./logging";

/**
 * Notificación de una noticia al publicarse (docs/news_contract.md §6).
 * La app se suscribe a `news-all{sufijo}` y `news-uni-{universidad}{sufijo}`;
 * aquí se envía a los temas de la audiencia y se marca `pushSentAt` una
 * sola vez.
 */

type Data = Record<string, unknown>;

export function topicSuffix(environment: DeploymentEnvironment): string {
  return environment === "production" ? "" : `-${environment}`;
}

/** Los temas de FCM solo admiten `[a-zA-Z0-9-_.~%]`. */
export function topicSafe(value: string): string {
  return value.trim().replace(/[^a-zA-Z0-9\-_.~]/g, "_").slice(0, 200);
}

export function newsTopics(environment: DeploymentEnvironment, universityIds: unknown): string[] {
  const suffix = topicSuffix(environment);
  const ids = Array.isArray(universityIds)
    ? universityIds.filter((id): id is string => typeof id === "string" && id.trim() !== "")
    : [];
  if (ids.length === 0) return [`news-all${suffix}`];
  return [...new Set(ids.map((id) => `news-uni-${topicSafe(id)}${suffix}`))];
}

function millis(value: unknown): number | null {
  return value instanceof Timestamp ? value.toMillis() : null;
}

/** Lista para enviar: publicada, con push, aún sin enviar y ya visible. */
export function shouldSendPush(data: Data | null | undefined, nowMillis: number): boolean {
  if (!data) return false;
  const publishAt = millis(data.publishAt);
  return data.status === "published"
    && data.push === true
    && (data.pushSentAt === undefined || data.pushSentAt === null)
    && publishAt !== null
    && publishAt <= nowMillis;
}

/** Título y texto de la notificación (cortos, como los ve el teléfono). */
export function pushContent(data: Data): { title: string; body: string } {
  const title = String(data.title ?? "").trim();
  const labels = Array.isArray(data.universityLabels)
    ? data.universityLabels.filter((l): l is string => typeof l === "string" && l !== "")
    : [];
  const prefix = data.priority === "urgent"
    ? `Aviso${labels.length ? ` ${labels.join(", ")}` : ""}: `
    : "";
  const body = String(data.body ?? "").replace(/\s+/g, " ").trim();
  return {
    title: `${prefix}${title}`.slice(0, 110),
    body: (body || "Toca para ver la noticia.").slice(0, 160)
  };
}

export function pushMessages(environment: DeploymentEnvironment, newsId: string, data: Data): Message[] {
  const { title, body } = pushContent(data);
  return newsTopics(environment, data.universityIds).map((topic) => ({
    topic,
    notification: { title, body },
    data: { newsId, route: `/news/${newsId}` },
    android: { priority: data.priority === "urgent" ? "high" : "normal" }
  }));
}

/**
 * Reserva el envío en una transacción (para no mandar dos veces si el
 * disparador y el job coinciden), envía y, si falla, libera la reserva.
 */
export async function sendNewsPush(config: BackendConfig, newsId: string): Promise<boolean> {
  const ref = db.collection(config.collections.news).doc(newsId);
  const data = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.data();
    if (!shouldSendPush(current, Date.now())) return null;
    tx.update(ref, { pushSentAt: Timestamp.now() });
    return current ?? null;
  });
  if (!data) return false;
  try {
    const messages = pushMessages(config.environment, newsId, data);
    const result = await getMessaging().sendEach(messages);
    if (result.successCount === 0) {
      throw new Error(result.responses.map((r) => r.error?.code ?? "unknown").join(","));
    }
    safeLog("news_push_sent", "system", {
      topics: messages.length,
      failed: result.failureCount
    });
    return true;
  } catch (error) {
    await ref.update({ pushSentAt: null });
    safeError("news_push_failed", error, {}, { environment: config.environment });
    return false;
  }
}

/** Las programadas: se envían cuando llega su hora. */
export async function sendDueNewsPushes(config: BackendConfig): Promise<number> {
  const pending = await db.collection(config.collections.news)
    .where("push", "==", true)
    .where("pushSentAt", "==", null)
    .limit(50)
    .get();
  let sent = 0;
  const now = Date.now();
  for (const doc of pending.docs) {
    if (shouldSendPush(doc.data(), now) && await sendNewsPush(config, doc.id)) sent++;
  }
  return sent;
}
