import assert from "node:assert/strict";
import test from "node:test";

import { accumulateAttempt, type StatsDelta } from "../src/question_stats";

test("suma respuestas por alternativa, aciertos y blancos", () => {
  const acc = new Map<string, StatsDelta>();
  const keys = new Map([["q1_1", "b"]]);
  const attempt = (answer?: string) => ({
    questions: [{ questionId: "q1", version: 1, alternatives: [{ id: "a", label: "A" }, { id: "b", label: "B" }] },
      { questionId: "q2", version: 1, alternatives: [{ id: "x", label: "A" }] }],
    answers: answer === undefined ? {} : { q1: answer, q2: "x" }
  });
  accumulateAttempt(acc, attempt("a"), keys);
  accumulateAttempt(acc, attempt("b"), keys);
  accumulateAttempt(acc, attempt("a"), keys);
  accumulateAttempt(acc, attempt(), keys);
  const q1 = acc.get("q1_1")!;
  assert.equal(q1.answered, 3);
  assert.equal(q1.blank, 1);
  assert.equal(q1.correct, 1);
  assert.deepEqual(q1.byAlternative, { a: 2, b: 1 });
  assert.deepEqual(q1.labels, { a: "A", b: "B" });
  assert.equal(acc.has("q2_1"), false, "sin clave no se cuenta");
});
