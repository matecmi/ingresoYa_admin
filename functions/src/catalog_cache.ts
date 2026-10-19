/**
 * Lista de cursos activos recordada por instancia (Fase 3C). La leían el
 * Simulador en modo aleatorio, el diagnóstico y el reto del día en cada
 * llamada: la colección completa cada vez.
 */
import type { Firestore } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import type { OperationMetrics } from "./operation_metrics";

export const CATALOG_CACHE_TTL_MS = 5 * 60 * 1000;

let cached: { key: string; ids: string[]; atMs: number } | undefined;

function isActive(data: Record<string, unknown> | undefined): boolean {
  const value = data?.active;
  return value !== false && value !== "N" && value !== "false" && value !== 0;
}

/** Ids de los cursos activos, en el orden de la colección. */
export async function activeCourseIds(
  db: Firestore,
  config: BackendConfig,
  metrics?: OperationMetrics,
  nowMs: number = Date.now()
): Promise<string[]> {
  const key = config.collections.courses;
  if (cached !== undefined && cached.key === key && nowMs - cached.atMs < CATALOG_CACHE_TTL_MS) {
    return cached.ids;
  }
  const courses = await db.collection(key).get();
  metrics?.readQuery(courses.size);
  const ids = courses.docs.filter((course) => isActive(course.data())).map((course) => course.id);
  cached = { key, ids, atMs: nowMs };
  return ids;
}

export function resetCatalogCache(): void {
  cached = undefined;
}
