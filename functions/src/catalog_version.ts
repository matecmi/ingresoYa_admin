/**
 * Versión del catálogo (docs/catalog_version_contract.md).
 *
 * Cada cambio en cursos, temas, subtemas (y sus partes) o universidades sube
 * un contador en `{config}/catalog`. La app lee ese documento al arrancar
 * (una lectura) y baja solo lo que cambió, en vez de escuchar la colección
 * completa de cursos y volver a bajar el árbol cada 30 minutos.
 */
import { FieldValue } from "firebase-admin/firestore";

import { db } from "./admin";
import { ACTIVE_COURSES_FIELD, scanActiveCourseIds } from "./catalog_cache";
import type { BackendConfig } from "./config";

/** Documento de `{config}` que guarda las versiones. */
export const CATALOG_DOC = "catalog";

export type CatalogKind = "courses" | "universities";

/** A qué familia del catálogo pertenece cada tipo auditado; null si a ninguna. */
export function catalogKindOf(kindKey: string): CatalogKind | null {
  switch (kindKey) {
    case "courses":
    case "topics":
    case "subtopics":
      return "courses";
    case "universities":
    case "universityChild":
      return "universities";
    default:
      return null;
  }
}

/**
 * Id del curso afectado según los parámetros de la ruta del disparador
 * (`{id}` en el curso, `{c}` en temas y subtemas). Vacío si no aplica.
 */
export function courseIdFromParams(kindKey: string, params: Record<string, string>): string {
  if (kindKey === "courses") return params.id ?? "";
  if (kindKey === "topics" || kindKey === "subtopics") return params.c ?? "";
  return "";
}

/**
 * Campos a fusionar en `{config}/catalog`: la familia sube su contador y, en
 * cursos, también el del curso tocado (`courseVersions.<id>`), para que la app
 * vuelva a bajar solo ese árbol.
 */
export function catalogBumpFields(
  kind: CatalogKind,
  courseId = "",
  activeCourseIds?: readonly string[]
): Record<string, unknown> {
  const fields: Record<string, unknown> = { updatedAt: FieldValue.serverTimestamp() };
  if (kind === "courses") {
    fields.coursesVersion = FieldValue.increment(1);
    if (courseId) fields.courseVersions = { [courseId]: FieldValue.increment(1) };
    // Lista completa de cursos activos (catalog_cache.ts): el Simulador la
    // lee aquí en una lectura en vez de recorrer la colección de cursos.
    if (activeCourseIds !== undefined) fields[ACTIVE_COURSES_FIELD] = [...activeCourseIds];
  } else {
    fields.universitiesVersion = FieldValue.increment(1);
  }
  return fields;
}

/**
 * Sube la versión (una escritura con merge; crea el documento si no existe).
 * Con [refreshActiveCourses] (un curso cambió, no un tema ni un subtema)
 * vuelve a guardar la lista de cursos activos: el admin edita cursos pocas
 * veces y así cada examen del Simulador se ahorra recorrer la colección.
 */
export async function bumpCatalogVersion(
  config: BackendConfig,
  kind: CatalogKind,
  courseId = "",
  refreshActiveCourses = false
): Promise<void> {
  const active = refreshActiveCourses ? await scanActiveCourseIds(db, config) : undefined;
  await db
    .collection(config.collections.config)
    .doc(CATALOG_DOC)
    .set(catalogBumpFields(kind, courseId, active), { merge: true });
}
