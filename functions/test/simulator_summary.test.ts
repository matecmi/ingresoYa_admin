import assert from "node:assert/strict";
import test from "node:test";

import { FieldValue } from "firebase-admin/firestore";

import { summaryUpdate, recentResultsMax, recentResultsUpdate, totalsUpdate } from "../src/simulator_service";

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

test("los últimos resultados van primero, sin repetir el intento y con tope", () => {
  const old = Array.from({ length: recentResultsMax }, (_, i) => ({ attemptId: `a${i}`, total: 10, universityId: "u" }));
  const next = recentResultsUpdate([...old, "x", null], { attemptId: "new", total: 20, universityId: "u", submittedAtMs: 5 });
  assert.equal(next.length, recentResultsMax);
  assert.deepEqual(next[0], { attemptId: "new", total: 20, submittedAtMs: 5 });
  assert.equal(next[1]?.attemptId, "a0");
  assert.equal(next[1]?.universityId, undefined);
  assert.equal(recentResultsUpdate(next, { attemptId: "a0", total: 3 }).filter((item) => item.attemptId === "a0").length, 1);
});

test("los totales se suman: absolutos la primera vez, incrementos después", () => {
  const latest = { total: 20, correct: 5, incorrect: 3, blank: 12, byCourse: [{ id: "alg", correct: 5, incorrect: 3, blank: 12 }] };
  const first = totalsUpdate({ exams: 13, questions: 230, correct: 50, incorrect: 40, blank: 140,
    recent: [{ byCourse: [{ id: "alg", correct: 2, incorrect: 1, blank: 7 }, { id: "geo", correct: 1, incorrect: 0, blank: 0 }] }] }, latest);
  assert.deepEqual(first, {
    exams: 14, questions: 250, correct: 55, incorrect: 43, blank: 152,
    byCourse: { alg: { correct: 7, incorrect: 4, blank: 19 }, geo: { correct: 1, incorrect: 0, blank: 0 } }
  });
  const next = totalsUpdate(undefined, latest);
  assert.ok((next.exams as FieldValue).isEqual(FieldValue.increment(1)));
  assert.ok((next.questions as FieldValue).isEqual(FieldValue.increment(20)));
  assert.ok(((next.byCourse as Record<string, Record<string, FieldValue>>).alg!.blank!).isEqual(FieldValue.increment(12)));
});
