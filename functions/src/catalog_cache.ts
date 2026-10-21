/**
 * Lista de cursos activos recordada por instancia (Fase 3C). La leían el
 * Simulador en modo aleatorio, el diagnóstico y el reto del día en cada
 * llamada: la colección completa cada vez. Desde 2026-10-20 sale de
 * `{config}/catalog.activeCourseIds` (una lectura; la mantiene el disparador
 * de cursos) y la colección queda solo de respaldo.
 */
import type { Firestore } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import { readConfigDoc } from "./config_cache";
import type { OperationMetrics } from "./operation_metrics";

/** Campo de `{config}/catalog` con los ids de los cursos activos, ordenados. */
export const ACTIVE_COURSES_FIELD = "activeCourseIds";

export const CATALOG_CACHE_TTL_MS = 5 * 60 * 1000;

let cached: { key: string; ids: string[]; atMs: number } | undefined;

export function isActive(data: Record<string, unknown> | undefined): boolean {
  const value = data?.active;
  return value !== false && value !== "N" && value !== "false" && value !== 0;
}

/** Ids de los cursos activos, en el orden de la colección (por id). */
export async function activeCourseIds(
  db: Firestore,
  config: BackendConfig,
  metrics?: OperationMetrics,
  nowMs: number = Date.now()
): Promise<string[]> {
  const key = config.collections.courses;
  const ttl = process.env.FIRESTORE_EMULATOR_HOST ? 0 : CATALOG_CACHE_TTL_MS;
  if (cached !== undefined && cached.key === key && nowMs - cached.atMs < ttl) {
    return cached.ids;
  }
  // `catalog` = CATALOG_DOC de catalog_version.ts (no se importa: arrastra admin.ts).
  const listed = (await readConfigDoc(db, config, "catalog", metrics, nowMs))?.[ACTIVE_COURSES_FIELD];
  const ids = Array.isArray(listed) && listed.every((id) => typeof id === "string")
    ? sortedIds(listed as string[])
    : await scanActiveCourseIds(db, config, metrics);
  cached = { key, ids, atMs: nowMs };
  return ids;
}

/** Lee la colección de cursos completa: respaldo y lo que guarda el disparador. */
export async function scanActiveCourseIds(
  db: Firestore,
  config: BackendConfig,
  metrics?: OperationMetrics
): Promise<string[]> {
  const courses = await db.collection(config.collections.courses).get();
  metrics?.readQuery(courses.size);
  return sortedIds(courses.docs.filter((course) => isActive(course.data())).map((course) => course.id));
}

/** El orden de la colección (por id), para que el reto del día sea igual en toda instancia. */
function sortedIds(ids: readonly string[]): string[] {
  return [...new Set(ids)].sort((left, right) => (left < right ? -1 : left > right ? 1 : 0));
}

export function resetCatalogCache(): void {
  cached = undefined;
}
