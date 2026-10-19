import type { DocumentReference, Firestore, Transaction } from "firebase-admin/firestore";
import { FieldValue, Timestamp } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import type { OperationMetrics } from "./operation_metrics";

/**
 * Preguntas que el alumno ya vio, en un solo documento
 * `{perfil}/{uid}/examMemory/recent` (reestructuración de costos: antes era
 * un documento por pregunta en `recentQuestions`, que costaba hasta 100
 * lecturas y 20 escrituras por examen). `q[questionId] = {t, n}`: la última
 * vez que la vio (ms) y cuántas veces. Solo el servidor lo lee y escribe.
 */
export interface SeenEntry {
  t: number;
  n: number;
}

export interface ExamMemoryState {
  seen: Map<string, SeenEntry>;
  /**
   * El documento aún no existía: [seen] salió de los registros antiguos de
   * `recentQuestions` y la primera escritura los copia al documento nuevo.
   */
  legacy: boolean;
}

/** Más que el mayor `simulatorSeenLimit` (500) y `recentQuestionLimit` (200). */
export const examMemoryMax = 600;

export function examMemoryRef(db: Firestore, config: BackendConfig, uid: string): DocumentReference {
  return db.collection(config.collections.users).doc(uid).collection("examMemory").doc("recent");
}

export function parseExamMemory(value: unknown): Map<string, SeenEntry> {
  const seen = new Map<string, SeenEntry>();
  const raw = value !== null && typeof value === "object" ? (value as Record<string, unknown>).q : undefined;
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return seen;
  for (const [id, entry] of Object.entries(raw as Record<string, unknown>)) {
    if (entry === null || typeof entry !== "object") continue;
    const { t, n } = entry as Record<string, unknown>;
    if (typeof t !== "number" || !Number.isFinite(t)) continue;
    seen.set(id, { t, n: typeof n === "number" && n > 0 ? n : 1 });
  }
  return seen;
}

/**
 * Una lectura. Si el documento no existe todavía (alumnos de antes del
 * cambio), lee una sola vez los registros antiguos para no perder la
 * ventana de repetición.
 */
export async function loadExamMemory(
  db: Firestore,
  config: BackendConfig,
  uid: string,
  metrics?: OperationMetrics
): Promise<ExamMemoryState> {
  const snapshot = await examMemoryRef(db, config, uid).get();
  metrics?.readDocument();
  if (snapshot.exists) return { seen: parseExamMemory(snapshot.data()), legacy: false };
  const old = await db
    .collection(config.collections.users)
    .doc(uid)
    .collection("recentQuestions")
    .orderBy("lastSeenAt", "desc")
    .limit(examMemoryMax)
    .get();
  metrics?.readQuery(old.size);
  const seen = new Map<string, SeenEntry>();
  for (const document of old.docs) {
    const data = document.data();
    const last = data.lastSeenAt;
    if (!(last instanceof Timestamp)) continue;
    seen.set(document.id, {
      t: last.toMillis(),
      n: typeof data.exposureCount === "number" && data.exposureCount > 0 ? data.exposureCount : 1
    });
  }
  return { seen, legacy: true };
}

/** Ids vistos desde [sinceMs], los más recientes primero, hasta [limit]. */
export function seenSince(state: ExamMemoryState, sinceMs: number, limit: number): Set<string> {
  return new Set(
    [...state.seen.entries()]
      .filter(([, entry]) => entry.t >= sinceMs)
      .sort((a, b) => b[1].t - a[1].t)
      .slice(0, limit)
      .map(([id]) => id)
  );
}

/** Las [limit] preguntas vistas más recientes con cuántas veces se vieron. */
export function recentExposure(state: ExamMemoryState, limit: number): Map<string, number> {
  return new Map(
    [...state.seen.entries()]
      .sort((a, b) => b[1].t - a[1].t)
      .slice(0, limit)
      .map(([id, entry]) => [id, entry.n])
  );
}

/**
 * Lo que hay que escribir al anotar [questionIds] como vistas en [now]:
 * una sola escritura con `merge`. Copia los registros antiguos la primera
 * vez y borra los más viejos al pasar de [examMemoryMax].
 */
export function exposureUpdate(
  state: ExamMemoryState,
  questionIds: readonly string[],
  now: number
): Record<string, unknown> {
  const merged = new Map(state.seen);
  for (const id of questionIds) merged.set(id, { t: now, n: (state.seen.get(id)?.n ?? 0) + 1 });
  const overflow = [...merged.entries()]
    .sort((a, b) => a[1].t - b[1].t)
    .slice(0, Math.max(0, merged.size - examMemoryMax))
    .map(([id]) => id);
  const dropped = new Set(overflow);
  const q: Record<string, unknown> = {};
  if (state.legacy) {
    for (const [id, entry] of merged) if (!dropped.has(id)) q[id] = { t: entry.t, n: entry.n };
  } else {
    for (const id of questionIds) if (!dropped.has(id)) q[id] = merged.get(id);
    for (const id of overflow) q[id] = FieldValue.delete();
  }
  return { schemaVersion: 1, updatedAtMs: now, q };
}

/** Anota [questionIds] dentro de la transacción que crea el intento. */
export function recordExposure(
  transaction: Transaction,
  db: Firestore,
  config: BackendConfig,
  uid: string,
  state: ExamMemoryState,
  questionIds: readonly string[],
  now: number
): void {
  transaction.set(examMemoryRef(db, config, uid), exposureUpdate(state, questionIds, now), { merge: true });
}
