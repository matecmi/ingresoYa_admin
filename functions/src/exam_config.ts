/**
 * Límites de selección de preguntas, editables desde el admin en
 * `{config}/exam` (docs/exam_config_contract.md, Fase 3C). Las variables de
 * entorno de `config.ts` quedan como respaldo cuando el documento no existe o
 * trae un valor fuera de rango.
 */
import { Timestamp, type Firestore } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import { readConfigDoc } from "./config_cache";
import type { OperationMetrics } from "./operation_metrics";

export interface ExamSelectionSettings {
  /** Escaneos aleatorios por bloque al armar un examen de la guía (1 a 8). */
  candidateStartsPerBlock: number;
  /** Candidatas por escaneo, también tope de los pools del Simulador (20 a 80). */
  maxCandidatesPerStart: number;
  /** Preguntas recientes del alumno que se consultan en la guía (1 a 200). */
  recentQuestionLimit: number;
  /** Preguntas vistas en la ventana de repetición que consulta el Simulador (20 a 500). */
  simulatorSeenLimit: number;
  /** Días que un intento enviado permanece en Firestore (30 a 730); después lo borra la TTL. */
  attemptRetentionDays: number;
}

export const SIMULATOR_SEEN_LIMIT_DEFAULT = 100;
export const ATTEMPT_RETENTION_DAYS_DEFAULT = 180;

const dayMs = 24 * 60 * 60 * 1000;

/** `expireAt` de un intento enviado (política TTL de `attempts`, Fase 4A). */
export function attemptExpireAt(nowMs: number, retentionDays: number): Timestamp {
  return Timestamp.fromMillis(nowMs + retentionDays * dayMs);
}

function bounded(value: unknown, fallback: number, min: number, max: number): number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max
    ? value
    : fallback;
}

export function parseExamSelection(
  data: Record<string, unknown> | undefined,
  fallback: BackendConfig["selection"]
): ExamSelectionSettings {
  const raw = data ?? {};
  return {
    candidateStartsPerBlock: bounded(raw.candidateStartsPerBlock, fallback.candidateStartsPerBlock, 1, 8),
    maxCandidatesPerStart: bounded(raw.maxCandidatesPerStart, fallback.maxCandidatesPerStart, 20, 80),
    recentQuestionLimit: bounded(raw.recentQuestionLimit, fallback.recentQuestionLimit, 1, 200),
    simulatorSeenLimit: bounded(raw.simulatorSeenLimit, SIMULATOR_SEEN_LIMIT_DEFAULT, 20, 500),
    attemptRetentionDays: bounded(raw.attemptRetentionDays, ATTEMPT_RETENTION_DAYS_DEFAULT, 30, 730)
  };
}

/** Los límites vigentes: `{config}/exam` (en caché por instancia) o el entorno. */
export async function loadExamSelection(
  db: Firestore,
  config: BackendConfig,
  metrics?: OperationMetrics
): Promise<ExamSelectionSettings> {
  return parseExamSelection(await readConfigDoc(db, config, "exam", metrics), config.selection);
}
