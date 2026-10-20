import type { DocumentReference, Firestore } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";

import type { BackendConfig } from "./config";
import { tokenCan } from "./audit";
import { ExamBackendError, asHttpsError, unauthenticated } from "./errors";
import { safeError, safeLog } from "./logging";
import { indexEntryOf, parseQuestionIndex } from "./question_index";

/**
 * Salud del contenido del Inicio del admin, calculada en el servidor y
 * guardada en `{adminReports}/contentHealth` (una lectura para el admin).
 * El documento guarda los datos que necesitan las reglas del admin
 * (`domain/content_health.dart`, `checkPart`): plantillas, preguntas
 * publicadas por parte (del índice por curso) y, por curso activo, sus temas,
 * subtemas y partes activas con lo que tiene cada una. Las reglas siguen en
 * un solo lugar (el admin) y el servidor solo junta los datos.
 *
 * Los disparadores marcan `dirtyAtMs` cuando cambia una pregunta, un curso,
 * un tema, un subtema o una plantilla (una escritura). El admin recalcula con
 * `refreshContentHealth` solo si el reporte falta, está marcado o lo pide
 * «Revisar ahora»: así una carga de 200 preguntas no recalcula 200 veces.
 */
export const CONTENT_HEALTH_DOC = "contentHealth";

export function contentHealthRef(db: Firestore, config: BackendConfig): DocumentReference {
  return db.collection(config.collections.adminReports).doc(CONTENT_HEALTH_DOC);
}

/** Mismo criterio que `ContentHealthRepo._active` del admin. */
export function isActive(value: unknown): boolean {
  if (value === null || value === undefined) return true;
  if (typeof value === "boolean") return value;
  const text = String(value).trim().toLowerCase();
  return text !== "false" && text !== "n" && text !== "0";
}

const text = (value: unknown): string => (value === null || value === undefined ? "" : String(value));
const filled = (value: unknown): boolean => text(value).trim().length > 0;
const count = (value: unknown): number => (Array.isArray(value) ? value.length : 0);
const asRecord = (value: unknown): Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};

/** Lo que tiene una parte, en corto (lo que mira `partElements`). */
export function partFacts(raw: Record<string, unknown>): Record<string, unknown> {
  return {
    id: text(raw.id),
    name: text(raw.name),
    order: text(raw.order),
    tpl: text(raw.examTemplateId).trim(),
    video: filled(raw.linkVideo),
    content: filled(raw.content),
    summary: filled(raw.summary),
    points: count(raw.keyPoints) + count(raw.objectives) > 0,
    examples: count(raw.examples),
    flash: count(raw.flashcards) > 0,
    res: filled(raw.linkPdf) || count(raw.externalLinks) > 0 || count(raw.images) > 0,
    quiz: count(raw.quizQuestions) > 0
  };
}

/** Plantilla tal como la usa el admin (`TemplateInfo`). */
export function templateFacts(id: string, data: Record<string, unknown>): Record<string, unknown> {
  const questionCount = Number(data.questionCount);
  const pass = data.passPercentExclusive;
  return {
    title: text(data.title ?? id) || id,
    n: Number.isFinite(questionCount) ? Math.trunc(questionCount) : 0,
    pass: pass === null || pass === undefined || !Number.isFinite(Number(pass)) ? null : Math.trunc(Number(pass)),
    ok: data.status === "published" && data.active !== false && data.purpose === "part_completion" && data.mode === "dynamic"
  };
}

/** Preguntas publicadas por parte, sumando los índices de todos los cursos. */
export function publishedByPart(indexDocs: unknown[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const doc of indexDocs) {
    for (const entry of parseQuestionIndex(doc)) {
      for (const partId of new Set(entry.partIds)) out[partId] = (out[partId] ?? 0) + 1;
    }
  }
  return out;
}

/** ¿El cambio de una pregunta mueve la salud? Solo si cambia su entrada del índice (curso o partes, o si deja de ser elegible). */
export function questionAffectsHealth(
  questionId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined
): boolean {
  const key = (data: Record<string, unknown> | undefined) => {
    const entry = indexEntryOf(questionId, data);
    if (entry === undefined) return "";
    const parts = Array.isArray(entry.value.p) ? [...(entry.value.p as string[])].sort() : [];
    return `${entry.courseId}|${parts.join(",")}`;
  };
  return key(before) !== key(after);
}

export async function markContentHealthDirty(db: Firestore, config: BackendConfig): Promise<void> {
  await contentHealthRef(db, config).set({ dirtyAtMs: Date.now() }, { merge: true });
}

export class ContentHealthService {
  constructor(
    private readonly db: Firestore,
    private readonly config: BackendConfig
  ) {}

  /** Recalcula y guarda el reporte; devuelve lo guardado. */
  async refresh(): Promise<Record<string, unknown>> {
    const startedAtMs = Date.now();
    const col = this.config.collections;
    let reads = 0;
    const [index, templates, courses] = await Promise.all([
      this.db.collection(col.questionIndex).get(),
      this.db.collection(col.templates).get(),
      this.db.collection(col.courses).get()
    ]);
    reads += index.size + templates.size + courses.size;
    const courseFacts = await Promise.all(
      courses.docs
        .filter((course) => isActive(course.data().active))
        .map(async (course) => {
          const topics = await course.ref.collection("topics").get();
          reads += topics.size;
          const topicFacts = await Promise.all(
            topics.docs.map(async (topic) => {
              const subtopics = await topic.ref.collection("subtopics").get();
              reads += subtopics.size;
              return {
                id: topic.id,
                name: text(topic.data().name),
                subtopics: subtopics.docs.map((sub) => {
                  const data = sub.data();
                  const parts = (Array.isArray(data.listPart) ? data.listPart : [])
                    .map(asRecord)
                    .filter((part) => isActive(part.active))
                    .map(partFacts);
                  return { id: sub.id, name: text(data.name), mastery: filled(data.masteryTemplateId), parts };
                })
              };
            })
          );
          return { id: course.id, name: text(course.data().name), topics: topicFacts };
        })
    );
    const report = {
      schemaVersion: 1,
      computedAtMs: startedAtMs,
      reads,
      templates: Object.fromEntries(templates.docs.map((doc) => [doc.id, templateFacts(doc.id, doc.data())])),
      published: publishedByPart(index.docs.map((doc) => doc.data())),
      courses: courseFacts
    };
    // merge: conserva `dirtyAtMs`; si llegó un cambio mientras se calculaba,
    // queda más nuevo que `computedAtMs` (la hora de inicio) y se recalcula.
    await contentHealthRef(this.db, this.config).set(report, { merge: true });
    return report;
  }
}

export function createContentHealthHandlers(db: Firestore, config: BackendConfig) {
  const service = new ContentHealthService(db, config);
  return {
    service,
    async refreshContentHealth(request: CallableRequest<unknown>) {
      try {
        const uid = request.auth?.uid;
        if (!uid) throw unauthenticated();
        if (!tokenCan(request.auth?.token as Record<string, unknown> | undefined, "courses", "v")) {
          throw new ExamBackendError("permission-denied", "Missing courses:v.", { reason: "staff_forbidden" });
        }
        const report = await service.refresh();
        safeLog("content_health_refreshed", uid, { reads: Number(report.reads) });
        return report;
      } catch (error) {
        safeError("content_health_refresh_rejected", error, {}, { environment: config.environment, uid: request.auth?.uid });
        throw asHttpsError(error);
      }
    }
  };
}
