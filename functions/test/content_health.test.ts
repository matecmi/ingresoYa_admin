import assert from "node:assert/strict";
import test from "node:test";
import { isActive, partFacts, publishedByPart, questionAffectsHealth, templateFacts } from "../src/content_health";

const question = (extra: Record<string, unknown> = {}) => ({
  schemaVersion: 2,
  status: "published",
  version: 1,
  randomKey: 0.5,
  sourceType: "original",
  difficulty: "easy",
  courseId: "c1",
  topicId: "t1",
  subtopicId: "s1",
  partIds: ["p1"],
  content: [],
  alternatives: [{ id: "a", label: "A", content: [] }, { id: "b", label: "B", content: [] }],
  ...extra
});

test("preguntas publicadas por parte salen del índice de cada curso", () => {
  const counts = publishedByPart([
    { q: { q1: { v: 1, d: "easy", o: "original", p: ["p1", "p2"] }, q2: { v: 1, d: "easy", o: "original", p: ["p1", "p1"] } } },
    { q: { q3: { v: 1, d: "easy", o: "original", p: ["p9"] }, q4: { v: 1, d: "easy", o: "original" } } },
    {}
  ]);
  assert.deepEqual(counts, { p1: 2, p2: 1, p9: 1 });
});

test("lo que tiene una parte y una plantilla, en corto", () => {
  assert.deepEqual(
    partFacts({ id: "p1", name: "Parte 1", order: 1, examTemplateId: " tpl ", linkVideo: "https://v", content: "", summary: "x", objectives: ["o"], examples: [{}, {}], images: [{}] }),
    { id: "p1", name: "Parte 1", order: "1", tpl: "tpl", video: true, content: false, summary: true, points: true, examples: 2, flash: false, res: true, quiz: false }
  );
  assert.deepEqual(templateFacts("t", { title: "Examen", questionCount: 10, passPercentExclusive: 60, status: "published", purpose: "part_completion", mode: "dynamic" }), {
    title: "Examen", n: 10, pass: 60, ok: true
  });
  assert.equal(templateFacts("t", { status: "draft" }).ok, false);
  assert.equal(templateFacts("t", {}).title, "t");
  assert.equal(isActive(undefined), true);
  assert.equal(isActive("N"), false);
  assert.equal(isActive(false), false);
});

test("solo marca la salud si cambia el curso, las partes o si la pregunta deja de contar", () => {
  assert.equal(questionAffectsHealth("q1", question(), question({ content: [{ type: "text" }], version: 2 })), false);
  assert.equal(questionAffectsHealth("q1", question(), question({ partIds: ["p1", "p2"] })), true);
  assert.equal(questionAffectsHealth("q1", question(), question({ status: "draft" })), true);
  assert.equal(questionAffectsHealth("q1", undefined, question()), true);
  assert.equal(questionAffectsHealth("q1", question({ status: "draft" }), question({ status: "draft", partIds: ["p3"] })), false);
});
