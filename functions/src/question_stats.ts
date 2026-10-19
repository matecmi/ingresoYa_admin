import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";

import type { BackendConfig } from "./config";
import { ExamBackendError, asHttpsError, unauthenticated } from "./errors";
import { safeError, safeLog } from "./logging";
import { tokenCan } from "./audit";

/**
 * Estadísticas por pregunta para «Preguntas a revisar» (rediseño del admin,
 * fase 7; docs/question_stats_contract.md). Suma, por versión de pregunta,
 * cuántas veces se respondió, cuántas en blanco, cuántas bien y cuántas veces
 * se eligió cada alternativa, a partir de los intentos entregados.
 */

interface AttemptQuestion {
  questionId: string;
  version: number;
  alternatives: { id: string; label: string }[];
}

export interface StatsDelta {
  questionId: string;
  version: number;
  answered: number;
  blank: number;
  correct: number;
  byAlternative: Record<string, number>;
  labels: Record<string, string>;
  correctAlternativeId: string;
}

const CURSOR_ID = "_cursor";
const PAGE = 200;

function questionsOf(attempt: Record<string, unknown>): AttemptQuestion[] {
  const raw = attempt.questions;
  if (!Array.isArray(raw)) return [];
  // Los intentos guardan {questionId, version, alternativeOrder} en `questions`
  // y el contenido (con las alternativas) en `questionSnapshots` (Fase 4B).
  const snapshots = new Map<string, Record<string, unknown>>();
  if (Array.isArray(attempt.questionSnapshots)) {
    for (const s of attempt.questionSnapshots as unknown[]) {
      if (s !== null && typeof s === "object" && typeof (s as Record<string, unknown>).questionId === "string") {
        snapshots.set((s as Record<string, unknown>).questionId as string, s as Record<string, unknown>);
      }
    }
  }
  const out: AttemptQuestion[] = [];
  for (const q of raw) {
    if (q === null || typeof q !== "object") continue;
    const r = q as Record<string, unknown>;
    if (typeof r.questionId !== "string" || typeof r.version !== "number") continue;
    const rawAlternatives = Array.isArray(r.alternatives) ? r.alternatives : snapshots.get(r.questionId)?.alternatives;
    const alternatives = Array.isArray(rawAlternatives)
      ? (rawAlternatives as unknown[])
        .filter((a): a is Record<string, unknown> => a !== null && typeof a === "object")
        .map((a) => ({ id: String(a.id ?? ""), label: String(a.label ?? "") }))
        .filter((a) => a.id !== "")
      : [];
    out.push({ questionId: r.questionId, version: r.version, alternatives });
  }
  return out;
}

/**
 * Suma un intento a los acumulados. `keys`: `${questionId}_${version}` →
 * alternativa correcta. Sin clave, la pregunta no se cuenta.
 */
export function accumulateAttempt(
  acc: Map<string, StatsDelta>,
  attempt: Record<string, unknown>,
  keys: ReadonlyMap<string, string>
): void {
  const answers = (attempt.answers ?? {}) as Record<string, unknown>;
  for (const q of questionsOf(attempt)) {
    const id = `${q.questionId}_${q.version}`;
    const correct = keys.get(id);
    if (correct === undefined) continue;
    let d = acc.get(id);
    if (!d) {
      d = {
        questionId: q.questionId,
        version: q.version,
        answered: 0,
        blank: 0,
        correct: 0,
        byAlternative: {},
        labels: Object.fromEntries(q.alternatives.map((a) => [a.id, a.label])),
        correctAlternativeId: correct
      };
      acc.set(id, d);
    }
    const chosen = answers[q.questionId];
    if (typeof chosen !== "string" || chosen === "") {
      d.blank += 1;
      continue;
    }
    d.answered += 1;
    d.byAlternative[chosen] = (d.byAlternative[chosen] ?? 0) + 1;
    if (chosen === correct) d.correct += 1;
  }
}

export class QuestionStatsService {
  public constructor(private readonly db: Firestore, private readonly config: BackendConfig) {}

  private get stats() {
    return this.db.collection(this.config.collections.questionStats);
  }

  /** Procesa los intentos entregados desde el último cursor. */
  public async refresh(maxAttempts = 3000): Promise<{ attempts: number; questions: number }> {
    const cursorRef = this.stats.doc(CURSOR_ID);
    const cursor = (await cursorRef.get()).data() ?? {};
    let since = cursor.submittedAt instanceof Timestamp ? cursor.submittedAt : Timestamp.fromMillis(0);
    let doneAtSince = new Set<string>(Array.isArray(cursor.doneIds) ? cursor.doneIds as string[] : []);
    let processed = 0;
    let questions = 0;
    const keyCache = new Map<string, string | null>();

    while (processed < maxAttempts) {
      const page = await this.db.collection(this.config.collections.attempts)
        .where("submittedAt", ">=", since)
        .orderBy("submittedAt")
        .limit(PAGE)
        .get();
      const fresh = page.docs.filter((d) => !doneAtSince.has(d.id));
      if (fresh.length === 0) break;

      // Claves de las preguntas de esta página (con caché).
      const needed = new Set<string>();
      for (const d of fresh) {
        for (const q of questionsOf(d.data())) {
          const id = `${q.questionId}_${q.version}`;
          if (!keyCache.has(id)) needed.add(id);
        }
      }
      const ids = [...needed];
      for (let i = 0; i < ids.length; i += 100) {
        const refs = ids.slice(i, i + 100).map((id) => this.db.collection(this.config.collections.answerKeys).doc(id));
        const snaps = refs.length ? await this.db.getAll(...refs) : [];
        snaps.forEach((s, j) => {
          const correct = s.data()?.correctAlternativeId;
          keyCache.set(ids[i + j]!, typeof correct === "string" ? correct : null);
        });
      }
      const keys = new Map([...keyCache].filter((e): e is [string, string] => e[1] !== null));

      const acc = new Map<string, StatsDelta>();
      for (const d of fresh) accumulateAttempt(acc, d.data(), keys);

      const batch = this.db.batch();
      for (const [id, d] of acc) {
        batch.set(this.stats.doc(id), {
          questionId: d.questionId,
          version: d.version,
          correctAlternativeId: d.correctAlternativeId,
          labels: d.labels,
          answered: FieldValue.increment(d.answered),
          blank: FieldValue.increment(d.blank),
          correct: FieldValue.increment(d.correct),
          byAlternative: Object.fromEntries(
            Object.entries(d.byAlternative).map(([k, v]) => [k, FieldValue.increment(v)])
          ),
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      }
      const last = page.docs[page.docs.length - 1]!;
      const lastAt = last.data().submittedAt as Timestamp;
      const sameAsLast = page.docs.filter((d) => (d.data().submittedAt as Timestamp).isEqual(lastAt)).map((d) => d.id);
      const nextDone = lastAt.isEqual(since) ? [...doneAtSince, ...sameAsLast] : sameAsLast;
      batch.set(cursorRef, { submittedAt: lastAt, doneIds: [...new Set(nextDone)].slice(-500), updatedAt: FieldValue.serverTimestamp() });
      await batch.commit();

      processed += fresh.length;
      questions += acc.size;
      since = lastAt;
      doneAtSince = new Set(nextDone);
      if (page.size < PAGE) break;
    }
    return { attempts: processed, questions };
  }
}

export function createQuestionStatsHandlers(db: Firestore, config: BackendConfig) {
  const service = new QuestionStatsService(db, config);
  return {
    service,
    async refreshQuestionStats(request: CallableRequest<unknown>) {
      try {
        const uid = request.auth?.uid;
        if (!uid) throw unauthenticated();
        if (!tokenCan(request.auth?.token as Record<string, unknown> | undefined, "questions", "v")) {
          throw new ExamBackendError("permission-denied", "Missing questions:v.", { reason: "staff_forbidden" });
        }
        const result = await service.refresh();
        safeLog("question_stats_refreshed", uid, { attempts: result.attempts, questions: result.questions });
        return result;
      } catch (error) {
        safeError("question_stats_refresh_rejected", error, {}, { environment: config.environment, uid: request.auth?.uid });
        throw asHttpsError(error);
      }
    }
  };
}
