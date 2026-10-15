import assert from "node:assert/strict";
import test from "node:test";

import { ExamBackendError } from "../src/errors";
import {
  groupResults,
  matchesPractice,
  officialScore,
  parsePastExamRules,
  parseSimulatorSettings,
  pickFresh,
  splitEvenly
} from "../src/simulator_service";
import type { CandidateQuestion } from "../src/exam_contracts";
import { parseCreateExamAttempt } from "../src/validation";

const rules = {
  questionCount: 100,
  durationMinutes: 180,
  maxScore: 1000,
  correctPoints: 4,
  incorrectPoints: -1,
  blankPoints: 0,
  questionOrder: "original",
  available: true,
  cutoffs: { "prof-1": 702, broken: "x" }
};

test("past exam rules keep valid cutoffs and reject impossible scoring", () => {
  const parsed = parsePastExamRules(rules);
  assert.deepEqual(parsed?.cutoffs, { "prof-1": 702 });
  assert.equal(parsed?.questionOrder, "original");
  assert.equal(parsePastExamRules({ ...rules, incorrectPoints: 1 }), undefined);
  assert.equal(parsePastExamRules({ ...rules, correctPoints: 0 }), undefined);
  assert.equal(parsePastExamRules({ ...rules, questionCount: 301 }), undefined);
  assert.equal(parsePastExamRules({ ...rules, blankPoints: 5 }), undefined);
  assert.equal(parsePastExamRules(null), undefined);
});

test("the official score is scaled to maxScore and never negative", () => {
  const scoring = { questionCount: 100, maxScore: 1000, correctPoints: 4, incorrectPoints: -1, blankPoints: 0 };
  assert.deepEqual(officialScore(scoring, { correct: 100, incorrect: 0, blank: 0 }), { rawScore: 400, score: 1000 });
  assert.deepEqual(officialScore(scoring, { correct: 70, incorrect: 20, blank: 10 }), { rawScore: 260, score: 650 });
  assert.deepEqual(officialScore(scoring, { correct: 2, incorrect: 98, blank: 0 }), { rawScore: -90, score: 0 });
});

test("settings fall back to factory values field by field", () => {
  const defaults = parseSimulatorSettings(undefined);
  assert.deepEqual(defaults.practiceSizes.map((size) => size.questions), [10, 20, 40]);
  assert.equal(defaults.repeatWindowDays, 14);
  assert.equal(defaults.showExplanations, true);
  const custom = parseSimulatorSettings({
    practiceSizes: [{ key: "x", label: "X", questions: 5, minutes: 10 }, { key: "y", label: "Y", questions: 12, minutes: 20 }],
    repeatWindowDays: 7,
    defaultSource: "real",
    showExplanations: false
  });
  assert.deepEqual(custom.practiceSizes.map((size) => size.key), ["y"]);
  assert.equal(custom.repeatWindowDays, 7);
  assert.equal(custom.defaultSource, "real");
  assert.equal(custom.showExplanations, false);
});

test("practice questions are shared evenly and filtered by source and difficulty", () => {
  assert.deepEqual([...splitEvenly(["a", "b", "c"], 10)], [["a", 4], ["b", 3], ["c", 3]]);
  assert.equal(matchesPractice({ sourceType: "admission_exam", difficulty: "hard" }, "real", "mixed"), true);
  assert.equal(matchesPractice({ sourceType: "original", difficulty: "hard" }, "real", "mixed"), false);
  assert.equal(matchesPractice({ sourceType: "official_practice", difficulty: "easy" }, "original", "mixed"), false);
  assert.equal(matchesPractice({ sourceType: "original", difficulty: "easy" }, "both", "hard"), false);
});

test("unseen questions come first and seen ones only fill the gap", () => {
  const pool = ["q1", "q2", "q3", "q4"].map((questionId) => ({ questionId }) as CandidateQuestion);
  const seen = new Set(["q1", "q2"]);
  const two = pickFresh(pool, 2, seen, new Set(), "seed");
  assert.deepEqual(two.map((question) => question.questionId).sort(), ["q3", "q4"]);
  const three = pickFresh(pool, 3, seen, new Set(["q4"]), "seed");
  assert.equal(three.length, 3);
  assert.equal(three[0]?.questionId, "q3");
  assert.equal(three.some((question) => question.questionId === "q4"), false);
});

test("results are grouped by course and topic", () => {
  const meta = new Map([
    ["q1", { questionId: "q1", courseId: "c1", topicId: "t1", subtopicId: "s1", partIds: [] }],
    ["q2", { questionId: "q2", courseId: "c1", topicId: "t2", subtopicId: "s2", partIds: [] }],
    ["q3", { questionId: "q3", courseId: "c2", topicId: "t3", subtopicId: "s3", partIds: [] }]
  ]);
  const { byCourse, byTopic } = groupResults([
    { questionId: "q1", selectedAlternativeId: "a", isCorrect: true },
    { questionId: "q2", selectedAlternativeId: "b", isCorrect: false },
    { questionId: "q3", selectedAlternativeId: null, isCorrect: false }
  ], meta);
  assert.deepEqual(byCourse, [
    { id: "c1", total: 2, correct: 1, incorrect: 1, blank: 0 },
    { id: "c2", total: 1, correct: 0, incorrect: 0, blank: 1 }
  ]);
  assert.equal(byTopic.length, 3);
});

test("create accepts past_exam and practice requests with strict shapes", () => {
  assert.deepEqual(
    parseCreateExamAttempt({ requestId: "r1", purpose: "past_exam", universityId: "u-1", examId: "e-1" }),
    { requestId: "r1", purpose: "past_exam", universityId: "u-1", examId: "e-1" }
  );
  assert.deepEqual(
    parseCreateExamAttempt({
      requestId: "r2", purpose: "practice", mode: "course", courseIds: ["c1"], topicIds: ["t1"],
      size: "normal", timed: false, source: "real", difficulty: "hard"
    }),
    {
      requestId: "r2", purpose: "practice", mode: "course", courseIds: ["c1"], topicIds: ["t1"],
      size: "normal", timed: false, source: "real", difficulty: "hard"
    }
  );
  assert.deepEqual(
    parseCreateExamAttempt({ requestId: "r3", purpose: "practice", mode: "mistakes", fromAttemptId: "a1", timed: false }),
    { requestId: "r3", purpose: "practice", mode: "mistakes", fromAttemptId: "a1", timed: false }
  );
  const invalid = (data: unknown) => assert.throws(
    () => parseCreateExamAttempt(data),
    (error: unknown) => error instanceof ExamBackendError && error.code === "invalid-argument"
  );
  invalid({ requestId: "r", purpose: "past_exam", examId: "e" });
  invalid({ requestId: "r", purpose: "past_exam", universityId: "u", examId: "e", extra: 1 });
  invalid({ requestId: "r", purpose: "practice", mode: "course", courseIds: ["a", "b"], size: "x", timed: true });
  invalid({ requestId: "r", purpose: "practice", mode: "mix", courseIds: ["a"], size: "x", timed: true });
  invalid({ requestId: "r", purpose: "practice", mode: "random", courseIds: ["a"], size: "x", timed: true });
  invalid({ requestId: "r", purpose: "practice", mode: "mix", courseIds: ["a", "b"], topicIds: ["t"], size: "x", timed: true });
  invalid({ requestId: "r", purpose: "practice", mode: "mix", courseIds: ["a", "a"], size: "x", timed: true });
  invalid({ requestId: "r", purpose: "practice", mode: "random", size: "x", timed: "yes" });
  invalid({ requestId: "r", purpose: "practice", mode: "random", size: "x", timed: true, source: "web" });
  invalid({ requestId: "r", purpose: "practice", mode: "mistakes", timed: true });
  invalid({ requestId: "r", purpose: "practice", mode: "mistakes", fromAttemptId: "a", timed: true, size: "x" });
});
