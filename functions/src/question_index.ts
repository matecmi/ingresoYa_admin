import type { DocumentReference, Firestore } from "firebase-admin/firestore";
import { FieldValue } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import { type CandidateQuestion, parseCandidateQuestion } from "./exam_contracts";
import type { OperationMetrics } from "./operation_metrics";

/**
 * Índice de preguntas publicadas por curso, `{questionIndex}/{courseId}`
 * (reestructuración de costos): con él el servidor elige las preguntas de un
 * examen del Simulador sin leer muestras de 40 preguntas; solo lee las que
 * eligió. Lo mantiene el disparador `indexQuestions` y solo lo lee el
 * servidor. `q[questionId] = {v, t, s, d, o, u}`: versión, tema, subtema,
 * dificultad, origen y universidad.
 */
export interface IndexEntry {
  id: string;
  version: number;
  topicId: string;
  subtopicId: string;
  difficulty: CandidateQuestion["difficulty"];
  sourceType: CandidateQuestion["sourceType"];
  universityId: string;
}

export function questionIndexRef(db: Firestore, config: BackendConfig, courseId: string): DocumentReference {
  return db.collection(config.collections.questionIndex).doc(courseId);
}

/** La entrada de una pregunta, o undefined si no es elegible (no publicada, mal formada). */
export function indexEntryOf(questionId: string, data: Record<string, unknown> | undefined): { courseId: string; value: Record<string, unknown> } | undefined {
  if (data === undefined) return undefined;
  const question = parseCandidateQuestion(questionId, data);
  if (question === undefined || question.courseId.length === 0) return undefined;
  return {
    courseId: question.courseId,
    value: {
      v: question.version,
      t: question.topicId,
      s: question.subtopicId,
      d: question.difficulty,
      o: question.sourceType,
      u: question.universityId
    }
  };
}

export function parseQuestionIndex(value: unknown): IndexEntry[] {
  const raw = value !== null && typeof value === "object" ? (value as Record<string, unknown>).q : undefined;
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return [];
  const entries: IndexEntry[] = [];
  for (const [id, item] of Object.entries(raw as Record<string, unknown>)) {
    if (item === null || typeof item !== "object") continue;
    const { v, t, s, d, o, u } = item as Record<string, unknown>;
    if (typeof v !== "number" || typeof d !== "string" || typeof o !== "string") continue;
    entries.push({
      id,
      version: v,
      topicId: typeof t === "string" ? t : "",
      subtopicId: typeof s === "string" ? s : "",
      difficulty: d as IndexEntry["difficulty"],
      sourceType: o as IndexEntry["sourceType"],
      universityId: typeof u === "string" ? u : ""
    });
  }
  // Orden estable: el sorteo por semilla no debe depender del orden del mapa.
  return entries.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}

/** Una lectura; undefined si el curso aún no tiene índice (se usa la consulta antigua). */
export async function loadQuestionIndex(
  db: Firestore,
  config: BackendConfig,
  courseId: string,
  metrics?: OperationMetrics
): Promise<IndexEntry[] | undefined> {
  const snapshot = await questionIndexRef(db, config, courseId).get();
  metrics?.readDocument();
  return snapshot.exists ? parseQuestionIndex(snapshot.data()) : undefined;
}

/**
 * Lo que cambia en los índices cuando una pregunta pasa de [before] a
 * [after]: se agrega o actualiza en su curso y se quita del curso anterior
 * (o del mismo, si dejó de estar publicada).
 */
export function indexChanges(
  questionId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined
): Map<string, Record<string, unknown>> {
  const changes = new Map<string, Record<string, unknown>>();
  const entry = indexEntryOf(questionId, after);
  const courseOf = (data: Record<string, unknown> | undefined) =>
    typeof data?.courseId === "string" && data.courseId.length > 0 ? data.courseId : undefined;
  for (const courseId of [courseOf(before), courseOf(after)]) {
    if (courseId !== undefined && courseId !== entry?.courseId) changes.set(courseId, { [questionId]: FieldValue.delete() });
  }
  if (entry !== undefined) changes.set(entry.courseId, { [questionId]: entry.value });
  return changes;
}

/** Disparador `indexQuestions`: mantiene los índices al publicar, editar o retirar. */
export async function syncQuestionIndex(
  db: Firestore,
  config: BackendConfig,
  questionId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined
): Promise<void> {
  const now = Date.now();
  await Promise.all(
    [...indexChanges(questionId, before, after).entries()].map(([courseId, q]) =>
      questionIndexRef(db, config, courseId).set({ schemaVersion: 1, updatedAtMs: now, q }, { merge: true })
    )
  );
}
