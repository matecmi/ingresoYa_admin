import assert from "node:assert/strict";
import test from "node:test";

import { FieldValue } from "firebase-admin/firestore";

import { summaryUpdate } from "../src/simulator_service";

const courses = new Map([["t1", "alg"], ["t2", "alg"], ["t3", "geo"]]);

test("con el resumen ya creado, cada tema sube con incrementos", () => {
  const update = summaryUpdate(undefined, [{ id: "t1", total: 4, correct: 3 }], courses, 1000) as {
    topics: Record<string, Record<string, unknown>>;
    migratedAtMs?: number;
  };
  assert.deepEqual(Object.keys(update.topics), ["t1"]);
  assert.equal(update.topics.t1!.courseId, "alg");
  assert.ok(update.topics.t1!.answered instanceof FieldValue);
  assert.equal(update.migratedAtMs, undefined);
});

test("la primera vez migra la subcolección antigua con valores absolutos", () => {
  const legacy: [string, Record<string, unknown>][] = [
    ["t1", { courseId: "alg", answered: 10, correct: 6 }],
    ["t3", { courseId: "geo", answered: 2, correct: 1 }]
  ];
  const update = summaryUpdate(legacy, [{ id: "t1", total: 4, correct: 3 }, { id: "t2", total: 2, correct: 2 }], courses, 5000) as {
    topics: Record<string, { courseId: string; answered: number; correct: number }>;
    migratedAtMs: number;
  };
  assert.equal(update.migratedAtMs, 5000);
  assert.deepEqual(update.topics.t1, { topicId: "t1", courseId: "alg", answered: 14, correct: 9, updatedAtMs: 5000 });
  assert.deepEqual(update.topics.t2, { topicId: "t2", courseId: "alg", answered: 2, correct: 2, updatedAtMs: 5000 });
  assert.deepEqual(update.topics.t3, { topicId: "t3", courseId: "geo", answered: 2, correct: 1, updatedAtMs: 5000 });
});
