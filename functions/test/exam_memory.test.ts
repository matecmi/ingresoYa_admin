import assert from "node:assert/strict";
import test from "node:test";
import { FieldValue } from "firebase-admin/firestore";

import { examMemoryMax, exposureUpdate, parseExamMemory, recentExposure, seenSince, type ExamMemoryState } from "../src/exam_memory";
import { indexChanges, indexEntryOf, parseQuestionIndex } from "../src/question_index";

const state = (entries: [string, number, number][], legacy = false): ExamMemoryState => ({
  seen: new Map(entries.map(([id, t, n]) => [id, { t, n }])),
  legacy
});

test("las preguntas vistas salen de un solo documento: ventana, orden y conteo", () => {
  const memory = state([["a", 100, 1], ["b", 300, 2], ["c", 200, 5]]);
  assert.deepEqual([...seenSince(memory, 150, 10)], ["b", "c"]);
  assert.deepEqual([...seenSince(memory, 0, 2)], ["b", "c"]);
  assert.deepEqual([...recentExposure(memory, 2)], [["b", 2], ["c", 5]]);
  assert.deepEqual(parseExamMemory({ q: { a: { t: 5, n: 2 }, bad: { n: 1 }, z: "x" } }), new Map([["a", { t: 5, n: 2 }]]));
});

test("anotar preguntas es una sola escritura: copia lo antiguo una vez y recorta lo más viejo", () => {
  // Primera vez (registros antiguos): copia todo y suma las nuevas.
  const first = exposureUpdate(state([["old", 10, 3]], true), ["old", "new"], 1000);
  assert.deepEqual(first.q, { old: { t: 1000, n: 4 }, new: { t: 1000, n: 1 } });
  // Ya migrado: solo escribe las nuevas.
  const next = exposureUpdate(state([["x", 10, 1]]), ["y"], 2000);
  assert.deepEqual(next.q, { y: { t: 2000, n: 1 } });
  // Lleno: borra las más viejas.
  const full = state(Array.from({ length: examMemoryMax }, (_, i) => [`q${i}`, i, 1] as [string, number, number]));
  const trimmed = exposureUpdate(full, ["fresh1", "fresh2"], 10_000).q as Record<string, unknown>;
  assert.deepEqual(trimmed.fresh1, { t: 10_000, n: 1 });
  assert.ok((trimmed.q0 as FieldValue).isEqual(FieldValue.delete()));
  assert.ok((trimmed.q1 as FieldValue).isEqual(FieldValue.delete()));
  assert.equal(trimmed.q2, undefined);
});

const published = (extra: Record<string, unknown> = {}) => ({
  schemaVersion: 2,
  status: "published",
  version: 3,
  randomKey: 0.4,
  sourceType: "original",
  difficulty: "hard",
  courseId: "c1",
  topicId: "t1",
  subtopicId: "s1",
  universityId: "u1",
  content: [],
  alternatives: [{ id: "a", label: "A", content: [] }, { id: "b", label: "B", content: [] }],
  ...extra
});

test("el índice del curso guarda lo justo y sigue a la pregunta al publicar, mover o retirar", () => {
  assert.deepEqual(indexEntryOf("q1", published()), { courseId: "c1", value: { v: 3, t: "t1", s: "s1", d: "hard", o: "original", u: "u1" } });
  assert.equal(indexEntryOf("q1", published({ status: "draft" })), undefined);
  // Publicar: entra en su curso.
  assert.deepEqual([...indexChanges("q1", undefined, published()).keys()], ["c1"]);
  // Mover de curso: sale del anterior y entra en el nuevo.
  const moved = indexChanges("q1", published(), published({ courseId: "c2" }));
  assert.ok((moved.get("c1")?.q1 as FieldValue).isEqual(FieldValue.delete()));
  assert.deepEqual(moved.get("c2")?.q1, { v: 3, t: "t1", s: "s1", d: "hard", o: "original", u: "u1" });
  // Retirar: sale.
  assert.ok((indexChanges("q1", published(), published({ status: "retired" })).get("c1")?.q1 as FieldValue).isEqual(FieldValue.delete()));
  assert.deepEqual(parseQuestionIndex({ q: { b: { v: 1, d: "easy", o: "original" }, a: { v: 2, d: "hard", o: "admission_exam", t: "t" } } }).map((entry) => entry.id), ["a", "b"]);
});
