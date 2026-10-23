/**
 * Peso de cada curso en el examen de la carrera del alumno
 * (docs/exam_areas_contract.md). La universidad guarda `examAreas[]` y
 * `careerDetails.{professionId}.examAreaId`; la práctica del día elige sus
 * cursos con estos pesos.
 */
import { createHash } from "node:crypto";

function record(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : undefined;
}

/** Σ preguntas × puntos por curso del área de [professionId]; vacío sin área. */
export function areaCourseWeights(
  university: Record<string, unknown> | undefined,
  professionId: string | undefined
): Map<string, number> {
  const weights = new Map<string, number>();
  if (university === undefined || professionId === undefined) return weights;
  const details = record(record(university.careerDetails)?.[professionId]);
  const areaId = typeof details?.examAreaId === "string" ? details.examAreaId : "";
  if (areaId.length === 0) return weights;
  const areas = Array.isArray(university.examAreas) ? university.examAreas : [];
  const area = areas.map(record).find((candidate) => candidate?.id === areaId);
  const rows = Array.isArray(area?.rows) ? area.rows : [];
  for (const raw of rows) {
    const row = record(raw);
    const courseId = typeof row?.courseId === "string" ? row.courseId : "";
    const questions = typeof row?.questions === "number" ? row.questions : 0;
    const points = typeof row?.points === "number" ? row.points : 0;
    if (courseId.length === 0 || questions <= 0 || points <= 0) continue;
    weights.set(courseId, (weights.get(courseId) ?? 0) + questions * points);
  }
  return weights;
}

function unit(seed: string): number {
  // (0, 1]: nunca 0, para que la potencia de abajo esté definida.
  return (createHash("sha256").update(seed).digest().readUInt32BE(0) + 1) / 2 ** 32;
}

/**
 * [count] cursos de [active] al azar pero con probabilidad según su peso
 * (muestreo sin reemplazo de Efraimidis–Spirakis, con semilla). Los cursos
 * sin peso solo completan si faltan.
 */
export function weightedCourses(
  active: readonly string[],
  weights: ReadonlyMap<string, number>,
  count: number,
  seed: string
): string[] {
  const keyed = active
    .map((courseId) => {
      const weight = weights.get(courseId) ?? 0;
      const u = unit(`${seed}:${courseId}`);
      return { courseId, weight, key: weight > 0 ? Math.pow(u, 1 / weight) : -u };
    })
    .sort((a, b) => b.key - a.key);
  return keyed.slice(0, count).map((entry) => entry.courseId);
}
